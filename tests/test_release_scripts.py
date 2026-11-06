"""Offline checks: no OSS uploads or production version writes."""
import ast
import contextlib
import importlib.util
import io
from pathlib import Path
import subprocess
import tempfile
import unittest
from unittest.mock import Mock, patch

ROOT = Path(__file__).resolve().parents[1]

def load(name):
    spec = importlib.util.spec_from_file_location(name, ROOT / (name + '.py'))
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module

class ReleaseScripts(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.modules = [load('bb_program_and_push'), load('bb_package_and_push')]

    def test_custom_headers_keep_auth_and_do_not_mutate_caller(self):
        for module in self.modules:
            headers = {'X-Trace': 'test'}
            response = Mock(status_code=200, headers={})
            response.json.return_value = {'code': 200, 'data': {}, 'msg': 'ok', 'rid': 'test'}
            with patch.object(module.requests, 'post', return_value=response) as post:
                self.assertEqual(module.httppost('/test', {}, headers)[0], 200)
                sent = post.call_args.kwargs['headers']
                self.assertEqual(sent['X-Trace'], 'test')
                self.assertTrue(sent['Authorization'].startswith('Token '))
                self.assertEqual(headers, {'X-Trace': 'test'})

    def test_versions_and_preset(self):
        app, package = self.modules
        self.assertEqual(app.get_cmd_version_code('26.1102.19'), 2611020019)
        self.assertEqual(package.get_cmd_version_code('26.1102.19'), 2611020019)
        self.assertEqual(app.get_app_version_code('1.1102.19'), 11102019)
        self.assertEqual(package.get_preset_value('AndroidHello', 'export_filter'), 'all_resources')

    def test_program_ini_and_configuration_filter(self):
        app = self.modules[0]
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            (root / 'export_presets.cfg').write_text('[preset.0]\ninclude_filter=""\n')
            with patch.object(app, 'PROJECT_ROOT', root):
                app.building_setup('26.1102.19')
                self.assertIn('build_pck_vcode = 2611020019', (root / 'configuration.ini').read_text())
                app.create_export_presets('include_filter', 'configuration.ini')
                self.assertIn('include_filter="configuration.ini"', (root / 'export_presets.cfg').read_text())
                app.remove_export_presets('include_filter', 'configuration.ini')
                self.assertIn('include_filter=""', (root / 'export_presets.cfg').read_text())

    def test_signing_keys_match_and_hash_is_correct(self):
        import base64, hashlib
        for module, key in zip(self.modules, ['public_key.pem', 'public_key.pem']):
            with tempfile.TemporaryDirectory() as directory:
                data = Path(directory) / 'data'; data.write_bytes(b'godothey-release-test')
                signature = Path(directory) / 'signature'
                signature.write_bytes(base64.b64decode(module.sign_file_rsa(data)))
                self.assertEqual(module.sha256_file(data), hashlib.sha256(data.read_bytes()).hexdigest())
                result = subprocess.run(['openssl', 'dgst', '-sha256', '-verify', str(ROOT / 'docs/signing' / key), '-signature', str(signature), str(data)], capture_output=True)
                self.assertEqual(result.returncode, 0)

    def test_version_record_payload_contract(self):
        app, package = self.modules
        with patch.object(package, 'httppost', return_value=(200, {}, '', '')) as post:
            package.create_pck_record('26.1102.19', {'url': 'https://example.test/test.pck', 'name': 'test.pck', 'mode': 'all_resources', 'size': 9, 'sha256': 'hash', 'sign': 'signature'})
            path, payload = post.call_args.args
            self.assertEqual(path, '/zzmdt/builded/uploadpck')
            self.assertEqual(payload['pck_hash'], 'hash')
            self.assertEqual(payload['pck_mode'], 'all_resources')
        with patch.object(app, 'httppost', return_value=(200, {}, '', '')) as post:
            app.create_version_record('1.1102.19', {'url':'zip','name':'a.zip','sha256':'hash','size':2}, {'url':'apk','name':'a.apk','sign':'signature','size':1})
            self.assertEqual(post.call_args.args[0], '/zzmdt/builded/uploadapp')
            self.assertEqual(post.call_args.args[1]['dist_sign'], 'signature')

    def test_main_fails_if_server_record_is_rejected(self):
        """Execute the real __main__ block with local build/upload substitutes."""
        for module in self.modules:
            tree = ast.parse((ROOT / (module.__name__ + '.py')).read_text())
            main = next(n for n in tree.body if isinstance(n, ast.If) and ast.unparse(n.test) == "__name__ == '__main__'")
            namespace = dict(module.__dict__)
            namespace['__name__'] = '__main__'
            with tempfile.TemporaryDirectory() as directory:
                output = Path(directory)
                def build(_preset, path): path.write_bytes(b'release-test')
                def zip_file(_src, path): path.write_bytes(b'zip-test')
                namespace.update(OUTPUT_PATH=output, get_app_version_name=lambda:'1.1102.19', get_cmd_version_name=lambda:'26.1102.19', building_setup=lambda *_:None, check_submit_allow=lambda *_:(200,{},'', ''), update_project_godot=lambda *_:None, update_export_presets=lambda *_:None, create_export_presets=lambda *_:None, remove_export_presets=lambda *_:None, build_godot_app=build, build_godot_pck=build, zip_file=zip_file, upload_to_oss=lambda *_args, **_kwargs:'https://example.test/test', sign_file_rsa=lambda *_:'signature', create_version_record=lambda *_args, **_kwargs:(500,{},'rejected',''), create_pck_record=lambda *_args, **_kwargs:(500,{},'rejected',''))
                with contextlib.redirect_stdout(io.StringIO()), self.assertRaises(SystemExit) as raised:
                    exec(compile(ast.Module(body=[main], type_ignores=[]), '<release-main-test>', 'exec'), namespace)
                self.assertEqual(raised.exception.code, 1)

if __name__ == '__main__':
    unittest.main()
