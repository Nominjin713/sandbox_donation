from django.contrib.auth.models import AbstractUser
from django.db import models
from django.conf import settings


class User(AbstractUser):
    email = models.EmailField(unique=True)
    name = models.CharField(max_length=100)
    email_verified = models.BooleanField(default=False)
    verification_digest = models.CharField(max_length=64, blank=True)
    verification_expires_at = models.DateTimeField(null=True, blank=True)
    verification_sent_at = models.DateTimeField(null=True, blank=True)
    verification_attempts = models.PositiveSmallIntegerField(default=0)


class AuthToken(models.Model):
    digest = models.CharField(max_length=64, unique=True)
    user = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE)
    expires_at = models.DateTimeField()
