"""Behavior checks use local fake tools; no subscription or network access."""
import importlib.util
import json
import os
from pathlib import Path
import signal
import subprocess
import sys
import tempfile
import time
from unittest.mock import patch

SCRIPT = Path(__file__).with_name("xray-speed-test.py")
spec = importlib.util.spec_from_file_location("speed", SCRIPT)
speed = importlib.util.module_from_spec(spec)
spec.loader.exec_module(speed)

MOCK = r'''
import json, os, socket, sys, time
from pathlib import Path
root=Path(os.environ['MOCK_ROOT'])
tool=Path(sys.argv[0]).name
args=sys.argv[1:]
with (root/'events').open('a') as stream:
    stream.write(json.dumps([tool,args,os.getpid()])+'\n')
if tool=='xray':
    conf=json.loads(Path(args[1]).read_text())
    sample=conf['outbounds'][0]['sample']
    if sample.get('startup')=='fail': sys.exit(1)
    if sample.get('startup')=='hang': time.sleep(30)
    port=conf['inbounds'][0]['port']
    with socket.socket() as server:
        server.bind(('127.0.0.1',port)); server.listen()
        (root/str(port)).write_text(json.dumps(sample))
        while True:
            connection,_=server.accept(); connection.close()
elif tool=='curl':
    assert args[0]=='-q'
    assert args[args.index('--noproxy')+1]==''
    assert args[args.index('--connect-timeout')+1]=='2'
    duration=args[args.index('--max-time')+1]
    assert duration in ('3','5')
    if args[-1].startswith('https://speed.cloudflare.com/'):
        assert args[args.index('--referer')+1]=='https://speed.cloudflare.com/'
    port=args[args.index('--socks5-hostname')+1].split(':')[1]
    sample=json.loads((root/port).read_text())
    if sample.get('slow'): time.sleep(30)
    rate=sample.get('final' if duration=='5' else 'rate',100)
    print(sample.get('metrics',f'200 {rate} 2000 2.2 0.2'),end='')
    sys.exit(sample.get('status',0))
elif tool=='sudo':
    os.execvp(args[0],args)
elif tool=='systemctl':
    if (root/'fail-restart').exists():
        (root/'fail-restart').unlink(); sys.exit(1)
'''


def check():
    with tempfile.TemporaryDirectory(prefix="speed-check-") as directory:
        root = Path(directory)
        bin_dir = root/'bin'
        bin_dir.mkdir()
        mock = bin_dir/'mock'
        mock.write_text(f'#!{sys.executable}\n'+MOCK)
        mock.chmod(0o755)
        for tool in ('xray', 'curl', 'systemctl', 'sudo'):
            (bin_dir/tool).symlink_to(mock)
        launcher = bin_dir/'xray-speed-test'
        launcher.write_text(f'#!/bin/sh\nexec {sys.executable} {SCRIPT} "$@"\n')
        launcher.chmod(0o755)
        subs = root/'subscriptions'
        subs.mkdir()
        env = dict(os.environ, PATH=f"{bin_dir}:{os.environ['PATH']}", MOCK_ROOT=str(root),
                   XRAY_CONF_DIR=str(root), XDG_CACHE_HOME=str(root/'cache'), XS_SYSTEMD_SCOPE='user')
        for name in ('XS_FILTER', 'XS_TEST_URL', 'XS_CONFIG_PATH'):
            env.pop(name, None)

        def node(name, **sample):
            (subs/name).write_text(json.dumps({'outbounds': [{'tag': 'proxy', 'sample': sample}]}))

        def run(*args, ok=True, overrides=None):
            result = subprocess.run([sys.executable, str(SCRIPT), *args], env=env |
                                    (overrides or {}), capture_output=True, text=True, timeout=20)
            assert (result.returncode == 0) == ok, result
            return json.loads(result.stdout) if result.stdout else None

        def events(tool):
            return [e for line in (root/'events').read_text().splitlines() if (e := json.loads(line))[0] == tool]
        node('Japan A.json', rate=400, final=10)
        node('Japan B.json', rate=300, final=500)
        node('Japan C.json', rate=200, final=50)
        node('Japan D.json', rate=100, final=1000)
        (subs/'active.json').symlink_to(subs/'Japan A.json')
        result = run()
        assert [s['file'] for s in result['results']] == [
            'Japan B.json', 'Japan C.json', 'Japan A.json']
        assert len(events('curl')) == 7
        assert not events('systemctl') and not events('sudo')
        assert (subs/'active.json').readlink().name == 'Japan A.json'
        assert not (root/'speed_test.json').exists()
        assert run()['cached'] and len(events('curl')) == 7
        run('--refresh')
        assert len(events('curl')) == 14
        # Changed contents, URL, new nodes and expired/malformed cache force new samples.
        node('Japan B.json', rate=301, final=501)
        assert not run()['cached']
        assert not run(overrides={'XS_TEST_URL': 'https://example.test/download'})['cached']
        for cache in (root/'cache'/'xray-speed-test').glob('*.json'):
            value = json.loads(cache.read_text())
            value['created_at'] = time.time()-601
            cache.write_text(json.dumps(value))
        assert not run()['cached']
        for cache in (root/'cache'/'xray-speed-test').glob('*.json'):
            cache.write_text('[]')
        assert not run()['cached']
        node('Japan E.json')
        assert not run()['cached']
        node('[JP]*?\n.json', rate=123)
        assert run('[JP]*?')['results'][0]['file'] == '[JP]*?\n.json'
        node('-Japan.json')
        assert run('--', '-Japan')['results']
        run('absent', ok=False)
        node('Timeout.json', status=28)
        assert run('Timeout')['results']
        node('Short.json', status=28, metrics='200 100 1 0.5 0.2')
        assert not run('Short', ok=False)['results']
        node('HTTP.json', metrics='503 100 1 2 0.2')
        assert not run('HTTP', ok=False)['results']
        node('Failure.json', startup='fail')
        assert not run('Failure', ok=False)['results']
        (subs/'Invalid.json').write_text('{}')
        assert not run('Invalid', ok=False)['results']
        # Occupied ports are not shared; the kernel assigns a different probe port.
        import socket
        with socket.socket() as occupied:
            occupied.bind(('127.0.0.1', 0))
            occupied.listen()
            assert run('Timeout', '--refresh')['results']
            last_conf = events('xray')[-1][1]
            assert last_conf[0] == '-c'
        # Bound startup waits and cleanup also apply to hung Xray processes.
        node('Hang.json', startup='hang')
        with patch.dict(os.environ, env), patch.dict(speed.PARAMS, startup_seconds=0.2):
            started = time.monotonic()
            assert not speed.measure(subs, 'Hang', True)['results']
            assert time.monotonic()-started < 3
        # A final-stage failure never falls back to quick samples.
        with patch.dict(os.environ, env), patch.object(speed, 'probe', side_effect=[
            {'file': 'Timeout.json', 'valid': True, 'bytes_per_second': 1},
                {'file': 'Timeout.json', 'valid': False, 'error': 'failed'}]):
            assert not speed.measure(subs, 'Timeout', True)['results']
        # xs keeps selection/cycling and system-scope override, using shared samples.
        xs = Path(__file__).with_name('xs.sh')

        def select(*args, overrides=None):
            return subprocess.run(['bash', str(xs), *args], env=env | (overrides or {}), capture_output=True, text=True, check=True)
        select('Japan B')
        assert (root/'config.json').readlink().name == 'Japan B.json'
        assert events('systemctl')[-1][1] == ['--user', 'restart', 'xray.service']
        select('Japan', overrides={'XS_SYSTEMD_SCOPE': 'system',
               'XS_CONFIG_PATH': str(subs/'active.json')})
        assert events('sudo')[-1][1] == ['systemctl', 'restart', 'xray.service']
        select('Japan')
        first = (root/'config.json').readlink()
        select('Japan')
        assert (root/'config.json').readlink() != first
        node('FinalFail.json', final=0)
        before = (root/'config.json').readlink()
        restarts = len(events('systemctl'))
        failed = subprocess.run(['bash', str(xs), 'FinalFail'], env=env, capture_output=True)
        assert failed.returncode != 0
        assert (root/'config.json').readlink() == before
        assert len(events('systemctl')) == restarts
        # Root-side switching refuses invalid targets and restores selection on failure.
        switch = Path(__file__).with_name('xray-switch.sh')
        previous = (subs/'active.json').readlink()
        for target in ('missing.json', '../Japan A.json', 'active.json'):
            assert subprocess.run(['bash', str(switch), str(subs), target], env=env).returncode
            assert (subs/'active.json').readlink() == previous
        (root/'fail-restart').touch()
        assert subprocess.run(['bash', str(switch), str(subs), 'Japan B.json'], env=env).returncode
        assert (subs/'active.json').readlink() == previous
        subprocess.run(['bash', str(switch), str(subs), 'Japan B.json'], env=env, check=True)
        assert (subs/'active.json').readlink().name == 'Japan B.json'
        # Asynchronous request transport, matching IDs, fixed worker URL and malformed input.
        queue = root/'queue'
        for part in ('requests', 'processing', 'results'):
            (queue/part).mkdir(parents=True)
        client = subprocess.Popen([sys.executable, str(SCRIPT), '--via-worker', '--queue-dir', str(
            queue), 'Japan B'], env=env, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
        deadline = time.monotonic()+5
        while not list((queue/'requests').glob('*.json')) and time.monotonic() < deadline:
            time.sleep(.02)
        token = 'a'*32
        speed.publish(queue/'requests'/f'{token}.json',
                      {'id': token, 'filter': 'Japan', 'refresh': 'bad'})
        subprocess.run([sys.executable, str(SCRIPT), '--worker', '--queue-dir', str(queue)],
                       env=env | {'XS_TEST_URL': 'https://ignored.test'}, check=True, timeout=20)
        output, _ = client.communicate(timeout=5)
        assert client.returncode == 0 and json.loads(output)['results']
        assert json.loads((queue/'results'/f'{token}.json').read_text())['error']
        assert not list((queue/'processing').iterdir())
        # Requests interrupted after claiming are recovered on the next worker run.
        recovered = 'b'*32
        speed.publish(queue/'processing'/f'{recovered}.json',
                      {'id': recovered, 'filter': 'Japan B', 'refresh': False})
        subprocess.run([sys.executable, str(SCRIPT), '--worker', '--queue-dir',
                       str(queue)], env=env, check=True, timeout=20)
        assert json.loads(
            (queue/'results'/f'{recovered}.json').read_text())['measurement']['results']
        # A worker timeout never consumes another request's successful result.
        with patch.object(speed.uuid, 'uuid4') as uid, patch.object(speed.time, 'monotonic', side_effect=[0, 100000]):
            uid.return_value.hex = 'c'*32
            try:
                speed.request(queue, subs, 'Japan', False)
            except ValueError as error:
                assert 'timed out' in str(error)
            else:
                raise AssertionError('missing worker timeout')
        assert not (queue/'requests'/('c'*32+'.json')).exists()
        # Missing worker directories fail before publishing any request.
        try:
            speed.request(root/'not-deployed', subs, 'Japan', False)
        except ValueError as error:
            assert 'not deployed' in str(error)
        else:
            raise AssertionError('missing deployment check')
        # Both curl and Xray are reaped on interruption.
        node('Interrupt.json', slow=True)
        for sig in (signal.SIGINT, signal.SIGTERM):
            count = len(events('curl'))
            process = subprocess.Popen([sys.executable, str(SCRIPT), 'Interrupt'],
                                       env=env, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
            deadline = time.monotonic()+5
            while len(events('curl')) == count and time.monotonic() < deadline:
                time.sleep(.02)
            assert len(events('curl')) == count+1
            process.send_signal(sig)
            process.communicate(timeout=5)
            assert process.returncode == 130
        for sig in (signal.SIGINT, signal.SIGTERM):
            count = len(events('curl'))
            process = subprocess.Popen(['bash', str(xs), 'Interrupt'],
                                       env=env, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
            deadline = time.monotonic()+5
            while len(events('curl')) == count and time.monotonic() < deadline:
                time.sleep(.02)
            assert len(events('curl')) == count+1
            process.send_signal(sig)
            process.communicate(timeout=5)
            assert process.returncode == 128+sig
        for tool in ('xray', 'curl'):
            for _, _, pid in events(tool):
                try:
                    os.kill(pid, 0)
                except ProcessLookupError:
                    pass
                else:
                    raise AssertionError(f'leaked {tool}: {pid}')
        print('xray speed-test and xs regression checks passed')


if __name__ == '__main__':
    check()
