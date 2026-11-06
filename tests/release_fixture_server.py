"""Loopback-only fixture endpoints for check_release_flow.py."""
import http.server
import json
from pathlib import Path

def handler_for(directory):
    directory = Path(directory)
    class Handler(http.server.BaseHTTPRequestHandler):
        def log_message(self, *_args):
            pass
        def send_json(self, data):
            payload = json.dumps(data).encode()
            self.send_response(200)
            self.send_header('Content-Type', 'application/json')
            self.send_header('Content-Length', str(len(payload)))
            self.end_headers()
            self.wfile.write(payload)
        def do_GET(self):
            payload = (directory / 'fixture.pck').read_bytes()
            self.send_response(200)
            self.send_header('Content-Length', str(len(payload)))
            self.end_headers()
            self.wfile.write(payload)
        def do_POST(self):
            data = json.loads(self.rfile.read(int(self.headers.get('Content-Length', 0))) or b'{}')
            if self.path.endswith('/initial'):
                if data.get('version_name') == 'test.offline':
                    self.send_json({'code': 503, 'msg': 'unavailable', 'data': {}})
                    return
                result = {'goto_scene': 'checking_upgrade' if data.get('version_name') == 'test.apk' else 'checking_update'}
            elif self.path.endswith('/upgrade'):
                result = {'upgrade_mode': 1, 'release_url': 'https://example.test/download', 'title': 'APK upgrade', 'intro': 'fixture'}
            else:
                result = {'update_mode': 3, 'title': 'Resource update', 'content': 'fixture', 'packages': [json.loads((directory / 'fixture.json').read_text())]}
            self.send_json({'code': 200, 'msg': 'ok', 'data': result})
    return Handler
