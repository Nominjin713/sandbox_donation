from django.urls import path
from accounts import views

urlpatterns = [
    path('health', views.health),
    path('auth/register', views.register),
    path('auth/login', views.login),
    path('auth/me', views.me),
    path('auth/logout', views.logout),
]
