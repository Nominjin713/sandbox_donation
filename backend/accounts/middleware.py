from django.conf import settings
from django.http import HttpResponse
from django.utils.cache import patch_vary_headers
from urllib.parse import urlsplit


def origin_allowed(origin):
    if origin == settings.CORS_ORIGIN:
        return True
    if not settings.DEBUG or not origin:
        return False
    try:
        parsed = urlsplit(origin)
        # Flutter assigns a different local port when --web-port is omitted.
        return (
            parsed.scheme in ('http', 'https')
            and parsed.hostname in ('localhost', '127.0.0.1', '::1')
            and parsed.username is None
            and parsed.password is None
            and not parsed.path
            and not parsed.query
            and not parsed.fragment
        )
    except ValueError:
        return False


class CorsMiddleware:
    def __init__(self, get_response):
        self.get_response = get_response

    def __call__(self, request):
        response = HttpResponse(status=204) if request.method == 'OPTIONS' else self.get_response(request)
        origin = request.headers.get('Origin', '')
        patch_vary_headers(response, ['Origin'])
        if origin_allowed(origin):
            response['Access-Control-Allow-Origin'] = origin
            response['Access-Control-Allow-Headers'] = 'Content-Type, Authorization'
            response['Access-Control-Allow-Methods'] = 'GET, POST, OPTIONS'
        response['Cache-Control'] = 'no-store'
        return response
