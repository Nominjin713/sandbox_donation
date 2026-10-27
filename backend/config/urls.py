from django.urls import path
from accounts import views
from django.urls import path, include
from django.conf import settings                    # ШИНЭ
from django.conf.urls.static import static          # ШИНЭ
from django.http import HttpResponse
from django.utils.html import escape


def api_index(request):
    endpoints = [
        ('GET', '/health', 'Серверийн төлөв'),
        ('POST', '/auth/register', 'Бүртгэл үүсгэх'),
        ('POST', '/auth/login', 'Нэвтрэх'),
        ('POST', '/auth/forgot-password', 'Нууц үг сэргээх хүсэлт'),
        ('POST', '/auth/reset-password', 'Нууц үг шинэчлэх'),
        ('GET', '/auth/me', 'Нэвтэрсэн хэрэглэгч'),
        ('POST', '/auth/logout', 'Гарах'),
        ('POST', '/auth/verify-email', 'Имэйл баталгаажуулах'),
        ('POST', '/auth/resend-verification', 'Баталгаажуулах код дахин илгээх'),
        ('GET', '/events/', 'Арга хэмжээний жагсаалт'),
        ('POST', '/events/create', 'Арга хэмжээ үүсгэх'),
        ('POST', '/events/upload-image/', 'Зураг upload хийх'),
        ('GET', '/events/<event_id>/', 'Арга хэмжээний дэлгэрэнгүй'),
        ('POST', '/events/<event_id>/edit', 'Арга хэмжээ засах'),
        ('POST', '/events/<event_id>/delete', 'Арга хэмжээ устгах'),
        ('POST', '/events/<event_id>/join', 'Арга хэмжээнд бүртгүүлэх'),
        ('POST', '/events/<event_id>/leave', 'Бүртгэл цуцлах'),
    ]
    rows = ''.join(
        f'<tr><td><code>{escape(method)}</code></td><td><code>{escape(path)}</code></td>'
        f'<td>{escape(description)}</td></tr>'
        for method, path, description in endpoints
    )
    return HttpResponse(
        '<!doctype html><html lang="mn"><meta charset="utf-8">'
        '<meta name="viewport" content="width=device-width, initial-scale=1">'
        '<title>Donation API</title><style>'
        'body{font:16px system-ui;max-width:900px;margin:40px auto;padding:0 18px;color:#252033}'
        'table{border-collapse:collapse;width:100%}th,td{text-align:left;padding:10px;border-bottom:1px solid #ddd}'
        'th{background:#f8f6ff}code{color:#7353ba}a{color:#7353ba}'
        '</style><h1>Donation API</h1><p>Үндсэн хаяг: <code>'
        f'{escape(request.scheme)}://{escape(request.get_host())}</code></p>'
        '<table><thead><tr><th>Method</th><th>Endpoint</th><th>Тайлбар</th></tr></thead>'
        f'<tbody>{rows}</tbody></table><p>GET endpoint-үүдийг нээж шалгаж болно. '
        'POST endpoint-д апп эсвэл API client ашиглана.</p></html>',
        content_type='text/html; charset=utf-8',
    )


urlpatterns = [
    path('', api_index, name='api_index'),
    path('health', views.health),
    path('auth/register', views.register),
    path('auth/login', views.login),
    path('auth/forgot-password', views.forgot_password),
    path('auth/reset-password', views.reset_password_view),
    path('auth/me', views.me),
    path('auth/logout', views.logout),
    path('auth/verify-email', views.verify),
    path('auth/resend-verification', views.resend_verification),
    path("events/", include("events.urls")),
]

urlpatterns += static(settings.MEDIA_URL, document_root=settings.MEDIA_ROOT)  # ШИНЭ
