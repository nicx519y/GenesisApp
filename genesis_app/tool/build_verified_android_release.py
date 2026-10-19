#!/usr/bin/env python3
"""Build ARM64 production APK, validate its actual manifest, archive provenance.

Does not install, upload, tag, or publish. A placeholder version is allowed for
local validation and is explicitly marked in release-evidence.json.
"""
import argparse
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
from datetime import datetime, timezone
import xml.etree.ElementTree as ET

APP = Path(__file__).resolve().parents[1]
ANDROID = '{http://schemas.android.com/apk/res/android}'


def run(*args, cwd=APP):
    return subprocess.check_output(args, cwd=cwd, text=True)


def sha256(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def validate_manifest(xml):
    root = ET.fromstring(xml)
    if root.get('package') != 'com.worldo.ai':
        raise ValueError('Unexpected application ID')
    providers = [p for p in root.findall('./application/provider')
                 if p.get(ANDROID + 'name') == 'androidx.startup.InitializationProvider']
    if len(providers) != 1:
        raise ValueError('Expected one AndroidX Startup provider')
    provider = providers[0]
    if provider.get(ANDROID + 'exported') != 'false':
        raise ValueError('Startup provider must not be exported')
    if provider.get(ANDROID + 'enabled', 'true') != 'true':
        raise ValueError('Startup provider must be enabled')
    if provider.get(ANDROID + 'authorities') != 'com.worldo.ai.androidx-startup':
        raise ValueError('Unexpected Startup authority')
    metadata = {m.get(ANDROID + 'name'): m.get(ANDROID + 'value')
                for m in provider.findall('meta-data')}
    if metadata.get('androidx.lifecycle.ProcessLifecycleInitializer') != 'androidx.startup':
        raise ValueError('Missing process lifecycle startup metadata')
    return {'version_name': root.get(ANDROID + 'versionName'),
            'version_code': root.get(ANDROID + 'versionCode'),
            'startup_metadata': metadata}


def source_state():
    return {
        'git_sha': run('git', 'rev-parse', 'HEAD').strip(),
        'diff_sha256': hashlib.sha256(run('git', 'diff', 'HEAD', '--binary').encode()).hexdigest(),
        'untracked': {path: sha256(APP.parent / path)
                      for path in run('git', 'ls-files', '--others', '--exclude-standard',
                                      '--full-name').splitlines()},
    }


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--build-name')
    parser.add_argument('--build-number', type=int)
    args = parser.parse_args()
    if bool(args.build_name) != (args.build_number is not None):
        parser.error('--build-name and --build-number must be supplied together')
    stamp = datetime.now(timezone.utc).strftime('%Y%m%dT%H%M%SZ')
    evidence = APP / 'build' / 'release-evidence' / stamp
    evidence.mkdir(parents=True)
    before = source_state()
    flutter = json.loads(run('flutter', '--version', '--machine'))
    symbols = evidence / 'symbols'
    command = ['flutter', 'build', 'apk', '--release', '--flavor', 'production',
               '--target-platform', 'android-arm64', f'--split-debug-info={symbols}',
               f'--dart-define=BUILD_GIT_SHA={before["git_sha"]}',
               f'--dart-define=BUILD_FLUTTER_VERSION={flutter["frameworkVersion"]}',
               f'--dart-define=BUILD_DIFF_SHA256={before["diff_sha256"]}']
    if args.build_name:
        command += [f'--build-name={args.build_name}', f'--build-number={args.build_number}']
    subprocess.run(command, cwd=APP, check=True)
    if source_state() != before:
        raise RuntimeError('Source changed during build; rebuild before claiming provenance')
    apk = APP / 'build/app/outputs/flutter-apk/app-production-release.apk'
    properties = dict(line.split('=', 1) for line in
                      (APP / 'android/local.properties').read_text().splitlines() if '=' in line)
    sdk = Path(os.environ.get('ANDROID_SDK_ROOT') or properties['sdk.dir'])
    analyzer = sdk / 'cmdline-tools/latest/bin/apkanalyzer'
    xml = run(str(analyzer), 'manifest', 'print', str(apk))
    manifest = validate_manifest(xml)
    (evidence / 'AndroidManifest.xml').write_text(xml)
    dependencies = run('./gradlew', ':app:dependencies', '--configuration',
                       'productionReleaseRuntimeClasspath', '--console=plain', cwd=APP / 'android')
    (evidence / 'android-dependencies.txt').write_text(dependencies)
    mapping = APP / 'build/app/outputs/mapping/productionRelease/mapping.txt'
    if not mapping.is_file() or not list(symbols.glob('*.symbols')):
        raise RuntimeError('Missing release mapping or Dart symbols')
    shutil.copy2(mapping, evidence / 'mapping.txt')
    shutil.copy2(apk, evidence / apk.name)
    (evidence / 'working-tree.patch').write_text(run('git', 'diff', 'HEAD', '--binary'))
    for path in before['untracked']:
        destination = evidence / 'untracked-sources' / path
        destination.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(APP.parent / path, destination)
    (evidence / 'release-evidence.json').write_text(json.dumps({
        **before, **manifest, 'built_at_utc': stamp, 'flutter': flutter,
        'build_command': command, 'apk_sha256': sha256(apk),
        'mapping_sha256': sha256(mapping),
        'dart_symbols': {p.name: sha256(p) for p in symbols.glob('*.symbols')},
        'placeholder_version': manifest['version_name'] == '9.9.9',
        'source_clean': not run('git', 'status', '--porcelain').strip(),
        'device_acceptance': 'not_performed', 'published': False,
    }, indent=2) + '\n')
    print(f'Validated APK and provenance: {evidence}')


if __name__ == '__main__':
    main()
