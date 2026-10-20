from django.urls import path
from . import views

urlpatterns = [
    path("", views.event_home, name="event_home"),
]