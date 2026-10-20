"""Registration and login business logic shared by authentication views."""
import hashlib
import secrets
from datetime import timedelta

from django.contrib.auth import authenticate
from django.conf import settings
from django.core.mail import send_mail
from django.utils.crypto import salted_hmac, constant_time_compare
from django.contrib.auth.password_validation import validate_password
from django.core.exceptions import ValidationError
from django.db import IntegrityError, transaction
from django.utils import timezone

from .models import AuthToken, User


class EmailAlreadyRegistered(Exception):
    pass


class VerificationRequired(Exception):
    pass


def code_digest(user, code):
    return salted_hmac('email-verification', f'{user.pk}:{code}', algorithm='sha256').hexdigest()


def send_verification(user):
    now = timezone.now()
    if user.verification_sent_at and now - user.verification_sent_at < timedelta(seconds=60):
        raise ValueError('Код дахин авахын өмнө 60 секунд хүлээнэ үү.')
    code = f'{secrets.randbelow(1000000):06d}'
    send_mail('Имэйл баталгаажуулах код', f'Таны баталгаажуулах код: {code}\nКод 10 минут хүчинтэй.', settings.DEFAULT_FROM_EMAIL, [user.email], fail_silently=False)
    user.verification_digest = code_digest(user, code)
    user.verification_expires_at = now + timedelta(minutes=10)
    user.verification_sent_at = now
    user.verification_attempts = 0
    user.save(update_fields=['verification_digest', 'verification_expires_at', 'verification_sent_at', 'verification_attempts'])


def verify_email(*, email, code):
    with transaction.atomic():
        user = User.objects.select_for_update().filter(email__iexact=email).first()
        if not user or user.email_verified or not user.is_active or not user.verification_expires_at or user.verification_expires_at <= timezone.now() or user.verification_attempts >= 5:
            return None
        user.verification_attempts += 1
        user.save(update_fields=['verification_attempts'])
        if not constant_time_compare(user.verification_digest, code_digest(user, code)):
            return None
        user.email_verified = True
        user.verification_digest = ''
        user.verification_expires_at = None
        user.save(update_fields=['email_verified', 'verification_digest', 'verification_expires_at'])
        return user, create_session(user)


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
            send_verification(user)
    except IntegrityError:
        if User.objects.filter(email__iexact=email).exists():
            raise EmailAlreadyRegistered from None
        raise
    return user


def login_user(*, request, email, password):
    existing_user = User.objects.filter(email__iexact=email.strip()).first()
    user = authenticate(request, username=existing_user.username if existing_user else email, password=password)
    if user is None:
        return None
    if not user.email_verified:
        raise VerificationRequired
    return user, create_session(user)
