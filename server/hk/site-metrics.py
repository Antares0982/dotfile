#!/usr/bin/env python3
import argparse
import datetime
import hashlib
import json
import os
import re
import subprocess
import sys
import tempfile
import urllib.parse


DB = "site_metrics"
BLOG_MARK = "blog-state-v1"
BADGE_MARK = "badge-counter-v1"
PAGE = re.compile(r"^/(?:[^?#]*/)?$")
BOT = re.compile(
    r"bot|spider|crawl|slurp|fetch|monitor|preview|scrape|"
    r"curl|wget|python-requests|httpx|go-http-client|headless|lighthouse",
    re.I,
)


def sql(text):
    proc = subprocess.run(
        ["mariadb", "--batch", "--skip-column-names", DB],
        input=text,
        text=True,
        stdout=subprocess.PIPE,
        check=True,
    )
    return proc.stdout.splitlines()


def sql_text(value):
    data = value.encode("utf-8").hex()
    return "''" if not data else f"CONVERT(0x{data} USING utf8mb4)"


def file_hash(path):
    digest = hashlib.sha256()
    with open(path, "rb") as source:
        for chunk in iter(lambda: source.read(65536), b""):
            digest.update(chunk)
    return digest.hexdigest()


def parse_blog(line):
    parts = line.rstrip("\n").split("\t")
    if len(parts) != 5:
        return None
    stamp, addr, status, uri, agent = parts
    if status != "200" or not agent or agent == "-" or BOT.search(agent):
        return None
    path = urllib.parse.unquote(uri.split("?", 1)[0])
    if len(addr) > 64 or len(path) > 512 or not PAGE.match(path):
        return None
    try:
        datetime.date.fromisoformat(stamp[:10])
    except ValueError:
        return None
    return stamp[:10], addr, path


def parse_badge(line):
    parts = line.rstrip("\n").split("\t")
    if len(parts) != 5 or parts[2] != "200":
        return False
    return parts[3].split("?", 1)[0] == "/api/visitor-badge.svg"


def read_part(path, position):
    with open(path, errors="replace") as source:
        info = os.fstat(source.fileno())
        if info.st_size < position:
            position = 0
        source.seek(position)
        lines = source.readlines()
        return lines, info.st_dev, info.st_ino, source.tell()


def get_cursor(stream):
    rows = sql(
        "SELECT device, inode, position FROM log_cursors "
        f"WHERE stream={sql_text(stream)};"
    )
    if not rows:
        return None
    device, inode, position = rows[0].split("\t")
    return int(device), int(inode), int(position)


def read_log(stream, path):
    cursor = get_cursor(stream)
    try:
        with open(path, errors="replace") as source:
            info = os.fstat(source.fileno())
            current = (info.st_dev, info.st_ino)
            if cursor is None or current == cursor[:2]:
                position = 0 if cursor is None else cursor[2]
                if info.st_size < position:
                    position = 0
                source.seek(position)
                return source.readlines(), (*current, source.tell())
    except FileNotFoundError:
        if cursor is None:
            return [], None
        raise

    rotated = path + ".1"
    try:
        old_lines, device, inode, _ = read_part(rotated, cursor[2])
    except FileNotFoundError as error:
        raise RuntimeError(f"missing rotated log for {stream}") from error
    if (device, inode) != cursor[:2]:
        raise RuntimeError(f"rotated log mismatch for {stream}")
    new_lines, device, inode, position = read_part(path, 0)
    return old_lines + new_lines, (device, inode, position)


def cursor_sql(stream, cursor):
    if cursor is None:
        return ""
    device, inode, position = cursor
    return (
        "INSERT INTO log_cursors(stream,device,inode,position) VALUES "
        f"({sql_text(stream)},{device},{inode},{position}) "
        "ON DUPLICATE KEY UPDATE device=VALUES(device),inode=VALUES(inode),"
        "position=VALUES(position);"
    )


def write_file(path, data):
    fd, temporary = tempfile.mkstemp(dir=os.path.dirname(path))
    try:
        mode = "wb" if isinstance(data, bytes) else "w"
        with os.fdopen(fd, mode) as output:
            output.write(data)
        os.chmod(temporary, 0o644)
        os.replace(temporary, path)
    except BaseException:
        if os.path.exists(temporary):
            os.unlink(temporary)
        raise


def make_output(out_dir):
    views = {}
    for row in sql("SELECT HEX(path), count FROM blog_views ORDER BY path;"):
        encoded, count = row.split("\t")
        views[bytes.fromhex(encoded).decode("utf-8")] = int(count)
    payload = json.dumps(
        views, ensure_ascii=False, separators=(",", ":"), sort_keys=True
    )
    write_file(os.path.join(out_dir, "views.json"), payload)

    rows = sql("SELECT count FROM badge_counts WHERE id='antares0982';")
    count = int(rows[0]) if rows else 0
    badge = subprocess.run(
        ["visitor-badge", str(count)], stdout=subprocess.PIPE, check=True
    ).stdout
    write_file(os.path.join(out_dir, "visitor-badge.svg"), badge)


def make_schema():
    sql(
        """
CREATE TABLE IF NOT EXISTS blog_views (
  path VARCHAR(512) CHARACTER SET utf8mb4 COLLATE utf8mb4_bin NOT NULL,
  count BIGINT UNSIGNED NOT NULL,
  PRIMARY KEY (path)
) ENGINE=InnoDB;
CREATE TABLE IF NOT EXISTS blog_seen (
  day DATE NOT NULL,
  addr VARCHAR(64) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
  path VARCHAR(512) CHARACTER SET utf8mb4 COLLATE utf8mb4_bin NOT NULL,
  PRIMARY KEY (day, addr, path)
) ENGINE=InnoDB;
CREATE TABLE IF NOT EXISTS badge_counts (
  id VARCHAR(64) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
  count BIGINT UNSIGNED NOT NULL,
  PRIMARY KEY (id)
) ENGINE=InnoDB;
CREATE TABLE IF NOT EXISTS log_cursors (
  stream VARCHAR(64) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
  device BIGINT UNSIGNED NOT NULL,
  inode BIGINT UNSIGNED NOT NULL,
  position BIGINT UNSIGNED NOT NULL,
  PRIMARY KEY (stream)
) ENGINE=InnoDB;
CREATE TABLE IF NOT EXISTS migrations (
  name VARCHAR(64) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
  source_path VARCHAR(512) NOT NULL,
  source_hash CHAR(64) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
  completed_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (name)
) ENGINE=InnoDB;
"""
    )


def marker_names():
    return set(sql("SELECT name FROM migrations;"))


def initial_cursor(path, position):
    info = os.stat(path)
    if info.st_size < position:
        position = 0
    return info.st_dev, info.st_ino, position


def import_old(args):
    make_schema()
    markers = marker_names()
    statements = ["START TRANSACTION;"]

    if BLOG_MARK not in markers:
        with open(args.blog_state) as source:
            state = json.load(source)
        counts = {}
        for path, count in state.get("counts", {}).items():
            key = urllib.parse.unquote(path)
            counts[key] = counts.get(key, 0) + int(count)
        for path, count in counts.items():
            statements.append(
                "INSERT INTO blog_views(path,count) VALUES "
                f"({sql_text(path)},{count}) ON DUPLICATE KEY UPDATE "
                "count=VALUES(count);"
            )
        day = state.get("day")
        if day:
            datetime.date.fromisoformat(day)
            for item in state.get("seen", []):
                addr, path = item.split("\t", 1)
                statements.append(
                    "INSERT IGNORE INTO blog_seen(day,addr,path) VALUES "
                    f"('{day}',{sql_text(addr)},{sql_text(path)});"
                )
        cursor = initial_cursor(args.blog_log, int(state.get("offset", 0)))
        statements.append(cursor_sql("blog", cursor))
        statements.append(
            "INSERT INTO migrations(name,source_path,source_hash) VALUES "
            f"('{BLOG_MARK}',{sql_text(args.blog_state)},"
            f"'{file_hash(args.blog_state)}');"
        )

    if BADGE_MARK not in markers:
        with open(args.badge_state) as source:
            count = int(source.read().strip())
        if count < 0:
            raise ValueError("negative badge count")
        statements.append(
            "INSERT INTO badge_counts(id,count) VALUES "
            f"('antares0982',{count}) ON DUPLICATE KEY UPDATE count=VALUES(count);"
        )
        statements.append(
            "INSERT INTO migrations(name,source_path,source_hash) VALUES "
            f"('{BADGE_MARK}',{sql_text(args.badge_state)},"
            f"'{file_hash(args.badge_state)}');"
        )

    statements.append("COMMIT;")
    sql("\n".join(statements))
    make_output(args.out_dir)


def update_db(args):
    blog_lines, blog_cursor = read_log("blog", args.blog_log)
    badge_lines, badge_cursor = read_log("badge", args.badge_log)
    statements = ["START TRANSACTION;"]

    for line in blog_lines:
        parsed = parse_blog(line)
        if parsed is None:
            continue
        day, addr, path = parsed
        statements.extend(
            [
                "INSERT IGNORE INTO blog_seen(day,addr,path) VALUES "
                f"('{day}',{sql_text(addr)},{sql_text(path)});",
                "SET @added=ROW_COUNT();",
                "INSERT INTO blog_views(path,count) "
                f"SELECT {sql_text(path)},1 WHERE @added=1 "
                "ON DUPLICATE KEY UPDATE count=count+1;",
            ]
        )

    badge_added = sum(parse_badge(line) for line in badge_lines)
    if badge_added:
        statements.append(
            "INSERT INTO badge_counts(id,count) VALUES "
            f"('antares0982',{badge_added}) ON DUPLICATE KEY UPDATE "
            f"count=count+{badge_added};"
        )
    statements.extend(
        [
            cursor_sql("blog", blog_cursor),
            cursor_sql("badge", badge_cursor),
            "DELETE FROM blog_seen WHERE day < "
            "(SELECT newest FROM (SELECT MAX(day) AS newest FROM blog_seen) AS days);",
            "COMMIT;",
        ]
    )
    sql("\n".join(item for item in statements if item))
    make_output(args.out_dir)
    print(f"blog lines={len(blog_lines)} badge views={badge_added}", file=sys.stderr)


def verify_old(args):
    rows = sql(
        "SELECT name, source_path, source_hash FROM migrations "
        f"WHERE name IN ('{BLOG_MARK}','{BADGE_MARK}');"
    )
    records = {row.split("\t", 2)[0]: row.split("\t", 2)[1:] for row in rows}
    expected = {
        BLOG_MARK: args.blog_state,
        BADGE_MARK: args.badge_state,
    }
    for name, path in expected.items():
        if name not in records:
            raise RuntimeError(f"missing migration marker: {name}")
        source_path, source_hash = records[name]
        if source_path != path or file_hash(path) != source_hash:
            raise RuntimeError(f"legacy source changed: {path}")

    with open(args.blog_state) as source:
        old_state = json.load(source)
    old_counts = {}
    for path, count in old_state.get("counts", {}).items():
        key = urllib.parse.unquote(path)
        old_counts[key] = old_counts.get(key, 0) + int(count)
    db_counts = {}
    for row in sql("SELECT HEX(path), count FROM blog_views;"):
        encoded, count = row.split("\t")
        db_counts[bytes.fromhex(encoded).decode("utf-8")] = int(count)
    for path, count in old_counts.items():
        if db_counts.get(path, -1) < count:
            raise RuntimeError(f"blog count regressed: {path}")

    with open(args.badge_state) as source:
        old_badge = int(source.read().strip())
    rows = sql("SELECT count FROM badge_counts WHERE id='antares0982';")
    if not rows or int(rows[0]) < old_badge:
        raise RuntimeError("badge count regressed")

    for name in ("views.json", "visitor-badge.svg"):
        path = os.path.join(args.out_dir, name)
        if not os.path.isfile(path) or not os.path.getsize(path):
            raise RuntimeError(f"missing output: {path}")


def clean_old(args):
    verify_old(args)
    for path in (
        args.blog_state,
        args.blog_output,
        args.badge_state,
        args.badge_state + ".tmp",
    ):
        try:
            os.unlink(path)
        except FileNotFoundError:
            pass
    for path in (os.path.dirname(args.blog_state), os.path.dirname(args.badge_state)):
        try:
            os.rmdir(path)
        except OSError:
            pass


def self_test():
    agent = "Mozilla/5.0"
    lines = [
        f"2026-08-19T10:00:00+08:00\t1.1.1.1\t200\t/post/?x=1\t{agent}",
        f"2026-08-19T10:00:01+08:00\t1.1.1.1\t200\t/post/\t{agent}",
        f"2026-08-19T10:00:02+08:00\t2.2.2.2\t200\t/\t{agent}",
        "2026-08-19T10:00:03+08:00\t3.3.3.3\t200\t/post/\tGooglebot",
    ]
    assert parse_blog(lines[0]) == ("2026-08-19", "1.1.1.1", "/post/")
    assert parse_blog(lines[1]) == ("2026-08-19", "1.1.1.1", "/post/")
    assert parse_blog(lines[2]) == ("2026-08-19", "2.2.2.2", "/")
    assert parse_blog(lines[3]) is None
    badge = f"2026-08-19T10:00:00+08:00\t1.1.1.1\t200\t/api/visitor-badge.svg\t{agent}"
    assert parse_badge(badge)
    assert not parse_badge(badge.replace("\t200\t", "\t304\t"))
    print("self-test ok")


def add_paths(parser):
    parser.add_argument("--blog-state", default="/var/lib/blog-views/state.json")
    parser.add_argument("--badge-state", default="/var/visitor/counterfile.txt")
    parser.add_argument("--blog-log", default="/var/log/nginx/blog-views.log")
    parser.add_argument("--badge-log", default="/var/log/nginx/visitor-badge.log")
    parser.add_argument("--out-dir", default="/var/lib/site-metrics")
    parser.add_argument("--blog-output", default="/var/lib/blog-views/views.json")


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--self-test", action="store_true")
    commands = parser.add_subparsers(dest="command")
    for name in ("init", "update", "verify", "clean"):
        add_paths(commands.add_parser(name))
    args = parser.parse_args()
    if args.self_test:
        self_test()
    elif args.command == "init":
        import_old(args)
    elif args.command == "update":
        update_db(args)
    elif args.command == "verify":
        verify_old(args)
    elif args.command == "clean":
        clean_old(args)
    else:
        parser.error("a command is required")


if __name__ == "__main__":
    main()
