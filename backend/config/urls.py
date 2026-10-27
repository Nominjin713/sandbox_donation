from django.urls import path
from accounts import views
from django.urls import path, include
from django.conf import settings                    # ШИНЭ
from django.conf.urls.static import static          # ШИНЭ


urlpatterns = [
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
