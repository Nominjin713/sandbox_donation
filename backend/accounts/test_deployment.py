import json
import os
from pathlib import Path
import secrets
import socket
import subprocess
import sys
import time
from urllib.error import URLError
from urllib.request import urlopen

from django.test import SimpleTestCase, override_settings

from .middleware import origin_allowed


@override_settings(DEBUG=False, CORS_ORIGIN='https://app.example.com',
                   CORS_ALLOWED_ORIGINS=['http://localhost:3000', 'https://app.example.com'])
class DeploymentCorsTests(SimpleTestCase):
    def test_production_allows_configured_clone_frontend(self):
        self.assertTrue(origin_allowed('http://localhost:3000'))
        self.assertTrue(origin_allowed('https://app.example.com'))

    def test_production_rejects_unconfigured_origin(self):
        self.assertFalse(origin_allowed('https://untrusted.example.com'))
        self.assertFalse(origin_allowed('http://localhost:4000'))
        self.assertFalse(origin_allowed('null'))

    @override_settings(ALLOWED_HOSTS=['testserver'])
    def test_preflight_allows_bearer_headers_only_for_allowed_origins(self):
        response = self.client.options('/auth/login', HTTP_ORIGIN='http://localhost:3000')
        self.assertEqual(response.status_code, 204)
        self.assertEqual(response['Access-Control-Allow-Origin'], 'http://localhost:3000')
        self.assertIn('Authorization', response['Access-Control-Allow-Headers'])
        rejected = self.client.options('/auth/login', HTTP_ORIGIN='https://untrusted.example.com')
        self.assertNotIn('Access-Control-Allow-Origin', rejected)


class ProductionServerTests(SimpleTestCase):
    def test_wsgi_health_endpoint_with_debug_disabled(self):
        with socket.socket() as listener:
            listener.bind(('127.0.0.1', 0))
            port = listener.getsockname()[1]
        env = {
            **os.environ, 'DJANGO_DEBUG': 'false', 'DJANGO_SECRET_KEY': secrets.token_urlsafe(64),
            'DJANGO_ALLOWED_HOSTS': '127.0.0.1', 'DATABASE_ENGINE': 'sqlite',
            'RUN_MIGRATIONS': 'false', 'PORT': str(port),
        }
        process = subprocess.Popen(
            [sys.executable, 'start_server.py'], cwd=Path(__file__).resolve().parents[1],
            env=env, stdout=subprocess.DEVNULL, stderr=subprocess.PIPE,
            creationflags=getattr(subprocess, 'CREATE_NO_WINDOW', 0),
        )
        try:
            deadline = time.monotonic() + 20
            while time.monotonic() < deadline:
                if process.poll() is not None:
                    self.fail('Production server exited: ' + process.stderr.read().decode(errors='replace'))
                try:
                    with urlopen(f'http://127.0.0.1:{port}/health', timeout=1) as response:
                        self.assertEqual(json.load(response), {'status': 'ok'})
                        return
                except URLError:
                    time.sleep(0.1)
            self.fail('Production server did not become healthy.')
        finally:
            if process.poll() is None:
                process.terminate()
                try:
                    process.wait(timeout=5)
                except subprocess.TimeoutExpired:
                    process.kill()
                    process.wait(timeout=5)
            process.stderr.close()
