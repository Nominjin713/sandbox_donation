from django.conf import settings
from django.http import HttpResponse


class CorsMiddleware:
    def __init__(self, get_response):
        self.get_response = get_response

    def __call__(self, request):
        response = HttpResponse(status=204) if request.method == 'OPTIONS' else self.get_response(request)
        if request.headers.get('Origin') == settings.CORS_ORIGIN:
            response['Access-Control-Allow-Origin'] = settings.CORS_ORIGIN
            response['Vary'] = 'Origin'
            response['Access-Control-Allow-Headers'] = 'Content-Type, Authorization'
            response['Access-Control-Allow-Methods'] = 'GET, POST, OPTIONS'
        response['Cache-Control'] = 'no-store'
        return response
