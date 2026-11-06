#!/usr/bin/env python3
"""Exercise Bootstrap/login/update/cold-start against loopback, with isolated saves."""
import http.server
import importlib.util
import os
from pathlib import Path
import subprocess
import tempfile
import threading

ROOT = Path(__file__).resolve().parents[1]
GODOT = os.environ.get('GODOT_BIN', '/Applications/Godot.app/Contents/MacOS/Godot')

def main():
    spec = importlib.util.spec_from_file_location('fixture_server', ROOT / 'tests/release_fixture_server.py')
    fixture_server = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(fixture_server)
    with tempfile.TemporaryDirectory(prefix='godothey-release-') as directory:
        work = Path(directory)
        project = work / 'project'
        project.mkdir()
        for source in (ROOT / 'project').iterdir():
            if source.name not in ['project.godot', 'export_presets.cfg']:
                (project / source.name).symlink_to(source, target_is_directory=source.is_dir())
        settings = (ROOT / 'project/project.godot').read_text()
        settings = settings.replace('[application]', '[application]\nconfig/use_custom_user_dir=true\nconfig/custom_user_dir="' + work.name + '"', 1)
        (project / 'project.godot').write_text(settings)
        server = http.server.ThreadingHTTPServer(('127.0.0.1', 0), fixture_server.handler_for(work))
        thread = threading.Thread(target=server.serve_forever, daemon=True)
        thread.start()
        address = 'http://127.0.0.1:' + str(server.server_address[1])
        environment = dict(os.environ, HTTP_BASE_URL=address, HTTPX_MDT_URL=address, RELEASE_FIXTURE_DIR=str(work))
        try:
            for suffix, marker in [([], 'RELEASE FLOW: PASS'), (['--', 'cold'], 'RELEASE COLD START: PASS')]:
                result = subprocess.run([GODOT, '--headless', '--path', str(project), '--script', 'res://tests/ReleaseFlow.gd', '--log-file', str(work / 'flow.log')] + suffix, env=environment, capture_output=True, text=True, timeout=90)
                if result.returncode or marker not in result.stdout or 'SCRIPT ERROR' in result.stdout + result.stderr:
                    print(result.stdout, result.stderr)
                    raise RuntimeError('Release flow failed')
                print(marker)
        finally:
            server.shutdown()
            server.server_close()
    print('No production uploads or version records were created.')

if __name__ == '__main__':
    main()
