"""Exercise routing and state boundaries, not generated shell text or aliases."""

import json
import os
from pathlib import Path
import pty
import shutil
import subprocess
import sys
import tempfile
import unittest

PROFILE = Path(sys.argv.pop(1)).resolve()
ZSH = str(PROFILE / "native/bin/zsh")


class WindowsShellTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory(prefix="windows-shell-test-")
        self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name)
        self.bin = self.root / "windows-bin"
        self.bin.mkdir()
        self.env = dict(os.environ)
        for key in ("AS_WINDOWS_SHELL", "_ANTARES_WS_PATH", "_ANTARES_WS_ZOXIDE",
                    "_ZO_DATA_DIR", "ZDOTDIR", "ZSH_CACHE_DIR", "ZSH_COMPDUMP"):
            self.env.pop(key, None)
        self.env.update(
            HOME=str(self.root), XDG_DATA_HOME=str(self.root / "data"),
            XDG_STATE_HOME=str(self.root / "state"), XDG_CACHE_HOME=str(self.root / "cache"),
            PROFILE=str(PROFILE), FIXTURES=str(self.bin), TERM="dumb",
        )
        # Do not accidentally execute the user's real Windows installations.
        self.env['PATH'] = os.pathsep.join(
            entry for entry in self.env['PATH'].split(os.pathsep)
            if not entry.startswith('/mnt/')
        )
        self.mock("git.exe", """
if sys.argv[1:] == ['version']:
    print('git version 2.50.0')
else:
    print(json.dumps({'args': sys.argv[1:], 'stdin': sys.stdin.read()}))
    sys.exit(23 if '--exit23' in sys.argv else 0)
""")
        self.mock("python.exe", "print(json.dumps(sys.argv[1:]))")

    def mock(self, name, code):
        target = self.bin / name
        target.write_text(f"#!{sys.executable}\nimport sys, os, json\n{code}\n")
        target.chmod(0o755)

    def run_zsh(self, code, *, active=True, interactive=False, input="", tty=False):
        env = dict(self.env)
        if active:
            env["AS_WINDOWS_SHELL"] = "1"
        # Windows executables are fixtures on /tmp. Add them AFTER exercising
        # the actual PATH filter, so the production filter remains unmodified.
        setup = 'source "$PROFILE/env.zsh"; path+=("$FIXTURES"); '
        if interactive:
            setup += 'source "$PROFILE/zshrc"; path+=("$FIXTURES"); '
        args = [ZSH, "-fic" if interactive else "-fc", setup + code]
        if not tty:
            return subprocess.run(args, env=env, input=input, text=True,
                                  capture_output=True, timeout=20)
        # The directory widget intentionally reads /dev/tty. Give it a
        # controlling terminal while keeping stdout available for assertions.
        master, slave = pty.openpty()
        try:
            def terminal():
                import fcntl
                import termios
                os.setsid()
                fcntl.ioctl(slave, termios.TIOCSCTTY, 0)
            proc = subprocess.Popen(args, env=env, stdin=slave, stdout=subprocess.PIPE,
                                    stderr=subprocess.PIPE, text=True, preexec_fn=terminal)
            stdout, stderr = proc.communicate(timeout=20)
            return subprocess.CompletedProcess(args, proc.returncode, stdout, stderr)
        finally:
            os.close(slave)
            os.close(master)

    def success(self, result):
        self.assertEqual(result.returncode, 0, result.stderr)
        return result.stdout

    def test_arguments_stdin_exit_and_child_process(self):
        args = ['space here', '中文', '$HOME', '*.txt', '; exit 9', '', '--exit23']
        # Positional parameters avoid a second shell parse of user arguments.
        code = """bash -c 'git "$@"' _ "space here" 中文 '$HOME' '*.txt' '; exit 9' "" --exit23"""
        result = self.run_zsh(code, input="pipe input\n")
        self.assertEqual(result.returncode, 23, result.stderr)
        self.assertEqual(json.loads(result.stdout), {'args': args, 'stdin': 'pipe input\n'})

    def test_missing_windows_command_never_runs_linux_namesake(self):
        self.mock("rg", "print('UNEXPECTED LINUX FALLBACK')")
        result = self.run_zsh('env rg needle')
        self.assertEqual(result.returncode, 127)
        self.assertNotIn('UNEXPECTED', result.stdout)

    def test_python3_uses_windows_python(self):
        self.assertEqual(json.loads(self.success(self.run_zsh('python3 hello'))), ['hello'])

    def test_npm_forwards_arguments_without_cmd_parsing(self):
        self.mock('node.exe', 'print(json.dumps(sys.argv[1:]))')
        self.mock('wslpath', 'print("C:/Node With Spaces/" + sys.argv[-1].rsplit("/", 1)[-1])')
        # Replace only the platform path converter for this test.
        result = self.run_zsh('path=("$FIXTURES" "${path[@]}"); npm "a & b" \'%PATH%\' ""')
        self.assertEqual(json.loads(self.success(result)),
                         ['C:/Node With Spaces/npm-cli.js', 'a & b', '%PATH%', ''])

    def test_path_filter_and_repeated_initialization(self):
        result = self.run_zsh('''
          path+=(/mnt/c/example /mnt/d/with\\ spaces /tmp/unapproved /run/current-system/sw/bin)
          source "$PROFILE/env.zsh"
          first=$PATH
          source "$PROFILE/env.zsh"
          [[ $PATH == $first ]] || exit 1
          for entry in "${path[@]}"; do print -r -- "$entry"; done
        ''')
        paths = self.success(result).splitlines()
        self.assertIn('/mnt/c/example', paths)
        self.assertIn('/mnt/d/with spaces', paths)
        self.assertNotIn('/tmp/unapproved', paths)
        self.assertNotIn('/run/current-system/sw/bin', paths)
        self.assertEqual(len(paths), len(set(paths)))

    def test_linux_escape_restores_environment(self):
        self.env['_ZO_DATA_DIR'] = str(self.root / 'original-zoxide')
        result = self.run_zsh('linux-shell zsh -fc \'print -r -- "$PATH"; print -r -- "$_ZO_DATA_DIR"; print -r -- "${AS_WINDOWS_SHELL-unset}"\'')
        self.assertEqual(self.success(result).splitlines(),
                         [self.env['PATH'], self.env['_ZO_DATA_DIR'], 'unset'])

    def test_nested_shell_and_explicit_mode_exit(self):
        result = self.run_zsh('''
          zsh -fc 'source "$PROFILE/env.zsh"; print -r -- "$_ZO_DATA_DIR"'
          AS_WINDOWS_SHELL=0 zsh -fc 'source "$PROFILE/env.zsh"; print -r -- "${_ZO_DATA_DIR-unset}"'
        ''')
        lines = self.success(result).splitlines()
        self.assertEqual(lines[0], str(self.root / 'data/windows-shell/zoxide'))
        self.assertEqual(lines[1], 'unset')

    def test_zoxide_databases_do_not_mix(self):
        for active, name in ((False, 'linux-project'), (True, 'windows-project')):
            directory = self.root / name
            directory.mkdir()
            self.env['VISIT'] = str(directory)
            self.success(self.run_zsh('mkdir -p "${_ZO_DATA_DIR:-$XDG_DATA_HOME/zoxide}"; zoxide add "$VISIT"', active=active))
        for active, name in ((False, 'linux-project'), (True, 'windows-project')):
            result = self.run_zsh('zoxide query --list', active=active)
            self.assertEqual(self.success(result).strip(), str(self.root / name))

    def test_history_files_do_not_mix(self):
        for active, marker in ((False, 'linux-history-marker'), (True, 'windows-history-marker')):
            self.env['MARKER'] = marker
            self.success(self.run_zsh('print -s -- "$MARKER"; fc -W "$HISTFILE"', active=active, interactive=True))
        for active, marker, other in ((False, 'linux-history-marker', 'windows-history-marker'),
                                      (True, 'windows-history-marker', 'linux-history-marker')):
            result = self.run_zsh('fc -R "$HISTFILE"; fc -ln 1', active=active, interactive=True)
            output = self.success(result)
            self.assertIn(marker, output)
            self.assertNotIn(other, output)

    def test_file_selection_quotes_paths_and_cancel_preserves_buffer(self):
        self.mock('rg.exe', "sys.stdout.buffer.write(b'file with spaces\\0semi;colon\\0')")
        self.mock('fzf.exe', "sys.stdout.buffer.write(sys.stdin.buffer.read())")
        result = self.run_zsh('''
          source "$PROFILE/interactive.zsh"
          zle() { :; }
          LBUFFER='bat '
          _windows_shell_files
          # Parse the quoted insertion as arguments without executing it.
          eval "set -- $LBUFFER"
          printf '%s\\0' "$@"
        ''')
        self.assertEqual(self.success(result).split('\0')[:-1], ['bat', 'file with spaces', 'semi;colon'])
        self.mock('fzf.exe', "sys.exit(130)")
        result = self.run_zsh('source "$PROFILE/interactive.zsh"; LBUFFER="keep me"; _windows_shell_files; print -r -- "$LBUFFER"')
        self.assertEqual(self.success(result).strip(), 'keep me')

    def test_directory_selection_and_cancel(self):
        target = self.root / 'empty dir' / 'child'
        target.mkdir(parents=True)
        self.mock('fzf.exe', "sys.stdout.buffer.write(b'empty dir\\\\child\\0')")
        result = self.run_zsh('''
          source "$PROFILE/interactive.zsh"
          zle() { :; }
          cd "$HOME"
          _windows_shell_directories
          print -r -- "$PWD"
        ''', tty=True)
        self.assertEqual(self.success(result).strip(), str(target))
        self.mock('fzf.exe', "sys.exit(130)")
        result = self.run_zsh('source "$PROFILE/interactive.zsh"; cd "$HOME"; _windows_shell_directories; print -r -- "$PWD"', tty=True)
        self.assertEqual(self.success(result).strip(), str(self.root))

    def test_early_file_selection_survives_producer_sigpipe(self):
        self.mock('rg.exe', """
try:
    for _ in range(10000):
        os.write(1, b'candidate\\0' * 1000)
except BrokenPipeError:
    os._exit(141)
""")
        self.mock('fzf.exe', "os.write(1, b'chosen\\0'); os._exit(0)")
        result = self.run_zsh('''
          source "$PROFILE/interactive.zsh"
          zle() { :; }
          setopt pipefail
          LBUFFER='bat '
          _windows_shell_files
          print -r -- "$LBUFFER"
        ''')
        self.assertEqual(self.success(result).strip(), 'bat chosen')

    def test_history_picker_preserves_multiline_commands(self):
        self.mock('fzf.exe', """
records = sys.stdin.buffer.read().split(b'\\0')
selected = next(row for row in records if row.endswith(b'\\tprintf first\\nprintf second'))
sys.stdout.buffer.write(selected + b'\\0')
""")
        result = self.run_zsh('''
          source "$PROFILE/interactive.zsh"
          zle() { :; }
          print -S -- $'printf first\\nprintf second'
          # The history parameter excludes the currently edited event.
          print -S -- ': next event'
          LBUFFER=''
          _windows_shell_history
          print -rn -- "$BUFFER"
        ''', interactive=True)
        self.assertEqual(self.success(result), 'printf first\nprintf second')

    def test_prompt_only_enables_git_for_windows_paths(self):
        result = self.run_zsh('''
          source "$PROFILE/interactive.zsh"
          PWD=/mnt/c/project
          _windows_shell_prompt_config
          print -r -- "$STARSHIP_CONFIG"
          PWD=$HOME
          _windows_shell_prompt_config
          print -r -- "$STARSHIP_CONFIG"
        ''')
        import tomllib
        windows, linux = self.success(result).splitlines()
        for path, enabled in ((windows, True), (linux, False)):
            config = tomllib.loads(Path(path).read_text())
            self.assertEqual(not config['git_status'].get('disabled', False), enabled)
            self.assertFalse(config['directory']['truncate_to_repo'])
            self.assertNotIn('repo_root_style', config['directory'])

    @unittest.skipUnless('microsoft' in os.uname().release.lower(), 'requires WSL Starship adapter')
    def test_windows_starship_failure_does_not_fall_back(self):
        repo = self.root / 'repo'
        repo.mkdir()
        subprocess.run([shutil.which('git'), 'init', '-q', str(repo)], check=True,
                       capture_output=True)
        (repo / 'untracked').write_text('would make native git_status nonempty')
        self.mock('wslpath', 'print("C:/test-repository")')
        self.mock('starship.exe', 'print("WINDOWS_STATUS", end="")')
        script = '''
          source "$PROFILE/interactive.zsh"
          PWD=/mnt/c/project
          _windows_shell_prompt_config
          path=("$FIXTURES" "${path[@]}")
          starship module git_status --path "$HOME/repo"
        '''
        self.assertEqual(self.success(self.run_zsh(script)), 'WINDOWS_STATUS')
        (self.bin / 'starship.exe').unlink()
        self.assertEqual(self.success(self.run_zsh(script)), '')


if __name__ == '__main__':
    unittest.main(verbosity=2)
