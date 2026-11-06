#!/usr/bin/env python3
"""Run UI/gameplay checks without touching the player's saves."""
import argparse
import os
from pathlib import Path
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]
GODOT = os.environ.get('GODOT_BIN', '/Applications/Godot.app/Contents/MacOS/Godot')

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--capture-dir', help='Also open a game window and save UI screenshots here.')
    args = parser.parse_args()
    with tempfile.TemporaryDirectory(prefix='godothey-ui-test-') as directory:
        work = Path(directory)
        for source in (ROOT / 'project').iterdir():
            if source.name not in ['project.godot', 'export_presets.cfg']:
                (work / source.name).symlink_to(source, target_is_directory=source.is_dir())
        settings = (ROOT / 'project/project.godot').read_text().replace('[application]', '[application]\nconfig/use_custom_user_dir=true\nconfig/custom_user_dir="' + work.name + '"', 1)
        (work / 'project.godot').write_text(settings)
        cases = [('FloatingJoystick', 'FLOATING JOYSTICK: PASS'), ('InventoryModes', 'INVENTORY AND MODES: PASS'), ('Integration', 'MEADOW INTEGRATION: PASS')]
        if args.capture_dir:
            cases.append(('CaptureInventory', 'INVENTORY UI CAPTURE: PASS'))
        for script, marker in cases:
            visual = script == 'CaptureInventory'
            environment = dict(os.environ)
            if visual: environment['UI_CAPTURE_DIR'] = str(Path(args.capture_dir).resolve())
            cmd = [GODOT, '--path', str(work), '--script', 'res://tests/' + script + '.gd', '--log-file', str(work / (script + '.log'))]
            cmd += ['--rendering-method', 'gl_compatibility'] if visual else ['--headless']
            result = subprocess.run(cmd, env=environment, capture_output=True, text=True, timeout=90)
            output = result.stdout + result.stderr
            if result.returncode or marker not in output or 'SCRIPT ERROR' in output or 'ERROR:' in output:
                print(output)
                raise RuntimeError(script + ' failed')
            print(marker)

if __name__ == '__main__':
    main()
