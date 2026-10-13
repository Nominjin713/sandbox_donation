"""Registration and login business logic shared by authentication views."""
import hashlib
import secrets
from datetime import timedelta

from django.contrib.auth import authenticate
from django.contrib.auth.password_validation import validate_password
from django.core.exceptions import ValidationError
from django.db import IntegrityError, transaction
from django.utils import timezone

from .models import AuthToken, User


class EmailAlreadyRegistered(Exception):
    pass


def token_digest(token):
    return hashlib.sha256(token.encode()).hexdigest()


def create_session(user):
    now = timezone.now()
    AuthToken.objects.filter(expires_at__lte=now).delete()
    token = secrets.token_hex(32)
    AuthToken.objects.create(user=user, digest=token_digest(token), expires_at=now + timedelta(hours=24))
    return token


def register_user(*, name, email, password):
    email = email.strip().lower()
    if User.objects.filter(email__iexact=email).exists():
        raise EmailAlreadyRegistered
    user = User(username=secrets.token_hex(16), email=email, name=name.strip())
    validate_password(password, user)
    try:
        with transaction.atomic():
            user.set_password(password)
            user.save()
            token = create_session(user)
    except IntegrityError:
        if User.objects.filter(email__iexact=email).exists():
            raise EmailAlreadyRegistered from None
        raise
    return user, token


def login_user(*, request, email, password):
    existing_user = User.objects.filter(email__iexact=email.strip()).first()
    user = authenticate(request, username=existing_user.username if existing_user else email, password=password)
    if user is None:
        return None
    return user, create_session(user)
