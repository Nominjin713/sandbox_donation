from django.urls import path
from . import views

urlpatterns = [
    path('create', views.create, name='event_create'),
    path('upload-image', views.upload_image, name='event_upload_image'),  # ← ШИНЭ
    path('<str:event_id>/join', views.participation, name='event_join'),
    path('<str:event_id>/leave', views.participation, {'cancel': True}, name='event_leave'),
    path('<str:event_id>/', views.detail, name='event_detail'),
    path("", views.event_home, name="event_home"),
]