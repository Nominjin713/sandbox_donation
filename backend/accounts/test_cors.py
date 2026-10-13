from django.http import HttpResponse
from django.test import SimpleTestCase, RequestFactory, override_settings

from .middleware import CorsMiddleware


@override_settings(DEBUG=True, CORS_ORIGIN='http://localhost:3000')
class CorsTests(SimpleTestCase):
    def response(self, origin, method='options'):
        request = getattr(RequestFactory(), method)('/auth/login', HTTP_ORIGIN=origin)
        return CorsMiddleware(lambda request: HttpResponse())(request)

    def test_flutter_random_local_port(self):
        for origin in ('http://localhost:61563', 'http://127.0.0.1:61563', 'http://[::1]:61563'):
            response = self.response(origin)
            self.assertEqual(response.status_code, 204)
            self.assertEqual(response['Access-Control-Allow-Origin'], origin)
        self.assertEqual(self.response('http://localhost:61563', 'get')['Access-Control-Allow-Origin'], 'http://localhost:61563')

    def test_remote_origins_are_rejected(self):
        for origin in ('http://example.com', 'http://localhost.example.com:61563', 'http://localhost@evil.example:61563', 'null'):
            self.assertNotIn('Access-Control-Allow-Origin', self.response(origin))

    @override_settings(DEBUG=False)
    def test_production_only_accepts_configured_origin(self):
        self.assertNotIn('Access-Control-Allow-Origin', self.response('http://localhost:61563'))
        self.assertEqual(self.response('http://localhost:3000')['Access-Control-Allow-Origin'], 'http://localhost:3000')
