import subprocess, sys, time, json, pathlib, datetime, xml.etree.ElementTree as ET

ROOT = pathlib.Path(__file__).resolve().parent
ADB = ['adb', '-s', '1A101FDF6006AX']
def run(*args):
    return subprocess.check_output(ADB + list(args), stderr=subprocess.STDOUT)
def record(action, **fields):
    data = dict(time=datetime.datetime.now(datetime.timezone(datetime.timedelta(hours=8))).isoformat(), action=action, **fields)
    with (ROOT / 'evidence/actions.jsonl').open('a') as f:
        f.write(json.dumps(data, ensure_ascii=False) + '\n')

args = sys.argv[1:]
action = args.pop(0)
if action == 'tap':
    run('shell', 'input', 'tap', *args)
elif action == 'swipe':
    run('shell', 'input', 'swipe', *args)
elif action == 'key':
    run('shell', 'input', 'keyevent', *args)
elif action == 'launch':
    run('shell', 'monkey', '-p', 'com.worldo.ai', '-c', 'android.intent.category.LAUNCHER', '1')
elif action == 'capture':
    name = args[0]
    if len(args) > 1: time.sleep(float(args[1]))
    path = ROOT / 'evidence' / name
    path.with_suffix('.png').write_bytes(run('exec-out', 'screencap', '-p'))
    if len(args) > 2 and args[2] == 'tree':
        run('shell', 'rm', '-f', '/sdcard/miniphone-test-window.xml')
        output = run('shell', 'uiautomator', 'dump', '/sdcard/miniphone-test-window.xml')
        path.with_suffix('.dump.txt').write_bytes(output)
        if b'UI hierchary dumped to:' in output:
            xml = run('exec-out', 'cat', '/sdcard/miniphone-test-window.xml')
            path.with_suffix('.xml').write_bytes(xml)
            for node in ET.fromstring(xml).iter('node'):
                label = node.get('text') or node.get('content-desc')
                if label: print(label[:180].replace('\n', ' / '), node.get('bounds'))
        else:
            print('No fresh UI tree:', output.decode())
    pid = run('shell', 'pidof', 'com.worldo.ai').decode().strip()
    audio = run('shell', 'dumpsys', 'audio').decode()
    lines = [line for line in audio.splitlines() if 'AudioPlaybackConfiguration' in line and ('/' + pid + ' ') in line]
    path.with_suffix('.audio.txt').write_text('pid=' + pid + '\n' + '\n'.join(lines) + '\n')
    print('AUDIO:', '\n'.join(lines) or 'No current player for app PID')
else:
    raise SystemExit('Unsupported action')
record(action, args=args)
