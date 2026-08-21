#!/usr/bin/env python3
"""Aggregate blog page views from nginx's log into a small JSON file.

The blog is a static site, so there is nothing in the request path that could
count a hit. Rather than add a service that every page load has to talk to,
this reads the log line nginx was already writing and rolls it up on a timer.
A page view therefore costs the server nothing beyond that line, and readers
fetch one small cached document for the whole site.

The numbers here are only the hits recorded since the WordPress migration; each
page carries its historical total in the HTML and adds the two. That keeps this
file purely additive -- it never needs seeding, and losing it costs recent
counts rather than all of them.

Log format (see server/hk/blog.nix), tab separated:

    $time_iso8601 \t $remote_addr \t $status \t $request_uri \t $http_user_agent
"""

import argparse
import json
import os
import re
import sys
import tempfile

# Every page on the site is a directory index, so a view is a request whose
# path ends in a slash. That drops assets, the feed and /api/views.json without
# needing to enumerate them.
PAGE = re.compile(r"^/(?:[^?#]*/)?$")

BOT = re.compile(
    r"bot|spider|crawl|slurp|fetch|monitor|preview|scrape|"
    r"curl|wget|python-requests|httpx|go-http-client|headless|lighthouse",
    re.I,
)


def parse(line):
    """Return (day, dedup_key, path) for a countable request, else None."""
    parts = line.rstrip("\n").split("\t")
    if len(parts) != 5:
        return None
    ts, addr, status, uri, ua = parts
    if status != "200":
        return None
    path = uri.split("?", 1)[0]
    if not PAGE.match(path):
        return None
    # An empty User-Agent is never a real reader and is the cheapest thing for
    # a crawler to send.
    if not ua or ua == "-" or BOT.search(ua):
        return None
    return ts[:10], addr + "\t" + path, path


def aggregate(state, lines):
    """Fold log lines into state. Returns the number of views added."""
    added = 0
    seen = set(state["seen"])
    for line in lines:
        parsed = parse(line)
        if parsed is None:
            continue
        day, key, path = parsed
        # One view per address per page per day, so a reader reloading a post
        # does not run the number up. The set is scoped to a single day, which
        # is what bounds its size.
        if day != state.get("day"):
            state["day"] = day
            seen = set()
        if key in seen:
            continue
        seen.add(key)
        state["counts"][path] = state["counts"].get(path, 0) + 1
        added += 1
    state["seen"] = sorted(seen)
    return added


def write_atomic(path, data):
    directory = os.path.dirname(path)
    fd, tmp = tempfile.mkstemp(dir=directory)
    try:
        with os.fdopen(fd, "w") as f:
            json.dump(data, f, ensure_ascii=False, separators=(",", ":"), sort_keys=True)
        os.chmod(tmp, 0o644)
        os.replace(tmp, path)
    except BaseException:
        if os.path.exists(tmp):
            os.unlink(tmp)
        raise


def run(log_path, state_path, out_path):
    try:
        with open(state_path) as f:
            state = json.load(f)
    except (FileNotFoundError, json.JSONDecodeError):
        state = {}
    state.setdefault("offset", 0)
    state.setdefault("counts", {})
    state.setdefault("seen", [])

    if not os.path.exists(log_path):
        return 0

    size = os.path.getsize(log_path)
    # logrotate replaced the file underneath us; start over from the top of the
    # new one rather than seeking past its end.
    if size < state["offset"]:
        state["offset"] = 0

    with open(log_path, errors="replace") as f:
        f.seek(state["offset"])
        added = aggregate(state, f)
        state["offset"] = f.tell()

    write_atomic(out_path, state["counts"])
    write_atomic(state_path, state)
    return added


def self_test():
    ua = "Mozilla/5.0"
    lines = [
        f"2026-08-19T10:00:00+08:00\t1.1.1.1\t200\t/xjb-vs-zmij/\t{ua}",
        # same reader, same page, same day -> not counted twice
        f"2026-08-19T10:00:05+08:00\t1.1.1.1\t200\t/xjb-vs-zmij/\t{ua}",
        # different reader -> counted
        f"2026-08-19T10:00:06+08:00\t2.2.2.2\t200\t/xjb-vs-zmij/\t{ua}",
        # query string must not fork the path
        f"2026-08-19T10:00:07+08:00\t3.3.3.3\t200\t/xjb-vs-zmij/?utm=x\t{ua}",
        # assets, feed and non-200s are not views
        f"2026-08-19T10:00:08+08:00\t4.4.4.4\t200\t/vendor/katex/katex.min.css\t{ua}",
        f"2026-08-19T10:00:09+08:00\t4.4.4.4\t200\t/index.xml\t{ua}",
        f"2026-08-19T10:00:10+08:00\t4.4.4.4\t404\t/nope/\t{ua}",
        # crawlers and blank agents are not views
        "2026-08-19T10:00:11+08:00\t5.5.5.5\t200\t/xjb-vs-zmij/\tGooglebot/2.1",
        "2026-08-19T10:00:12+08:00\t6.6.6.6\t200\t/xjb-vs-zmij/\t-",
        # the root page counts
        f"2026-08-19T10:00:13+08:00\t7.7.7.7\t200\t/\t{ua}",
    ]
    state = {"offset": 0, "counts": {}, "seen": []}
    assert aggregate(state, lines) == 4, state
    assert state["counts"] == {"/xjb-vs-zmij/": 3, "/": 1}, state["counts"]

    # A new day clears the dedup set, so the same reader counts again.
    assert aggregate(state, [f"2026-08-20T09:00:00+08:00\t1.1.1.1\t200\t/xjb-vs-zmij/\t{ua}"]) == 1
    assert state["counts"]["/xjb-vs-zmij/"] == 4
    assert state["day"] == "2026-08-20"
    assert state["seen"] == ["1.1.1.1\t/xjb-vs-zmij/"]

    print("self-test ok")


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--log", default="/var/log/nginx/blog-views.log")
    ap.add_argument("--state", default="/var/lib/blog-views/state.json")
    ap.add_argument("--out", default="/var/lib/blog-views/views.json")
    ap.add_argument("--self-test", action="store_true")
    args = ap.parse_args()

    if args.self_test:
        self_test()
        return

    added = run(args.log, args.state, args.out)
    print(f"added {added} views", file=sys.stderr)


if __name__ == "__main__":
    main()
