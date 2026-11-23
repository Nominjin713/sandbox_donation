"""Registration and login business logic shared by authentication views."""
import hashlib
import logging
import secrets
from datetime import timedelta

from django.conf import settings
from django.contrib.auth import authenticate
from django.contrib.auth.password_validation import validate_password
from django.core.mail import send_mail
from django.db import IntegrityError, transaction
from django.utils import timezone
from django.utils.crypto import constant_time_compare, salted_hmac
import json
import os
import urllib.request
from .models import AuthToken, User

logger = logging.getLogger(__name__)

RESEND_COOLDOWN = timedelta(seconds=60)
CODE_LIFETIME = timedelta(minutes=10)
MAX_ATTEMPTS = 5


class EmailAlreadyRegistered(Exception):
    pass


class VerificationRequired(Exception):
    pass


class VerificationCooldown(ValueError):
    """Код дахин авахын өмнө хүлээх шаардлагатай."""


class EmailSendFailed(Exception):
    """SMTP / имэйл үйлчилгээ алдаа өгсөн."""


def _new_code():
    return f'{secrets.randbelow(1000000):06d}'


def _send_via_brevo(subject, message, to_email):
    payload = json.dumps({
        'sender': {'name': 'Donation', 'email': os.environ['MAIL_SENDER_EMAIL']},
        'to': [{'email': to_email}],
        'subject': subject,
        'textContent': message,
    }).encode('utf-8')
    req = urllib.request.Request(
        'https://api.brevo.com/v3/smtp/email',
        data=payload,
        headers={
            'api-key': os.environ['BREVO_API_KEY'],
            'content-type': 'application/json',
            'accept': 'application/json',
            'user-agent': 'donation-backend',
        },
        method='POST',
    )
    with urllib.request.urlopen(req, timeout=15) as resp:
        resp.read()


def _safe_send_mail(subject, message, to_email):
    try:
        if os.environ.get('BREVO_API_KEY'):
            _send_via_brevo(subject, message, to_email)
        else:
            send_mail(
                subject,
                message,
                settings.DEFAULT_FROM_EMAIL,
                [to_email],
                fail_silently=False,
            )
    except Exception as exc:
        logger.exception('Email send failed')
        raise EmailSendFailed from exc

# ---------------------------------------------------------------- verification

def code_digest(user, code):
    return salted_hmac(
        'email-verification', f'{user.pk}:{code}', algorithm='sha256'
    ).hexdigest()


def _check_verification_cooldown(user):
    if user.verification_sent_at and timezone.now() - user.verification_sent_at < RESEND_COOLDOWN:
        raise VerificationCooldown('Код дахин авахын өмнө 60 секунд хүлээнэ үү.')


def send_verification(user):
    _check_verification_cooldown(user)
    now = timezone.now()
    code = _new_code()
    _safe_send_mail(
        'Имэйл баталгаажуулах код',
        f'Таны баталгаажуулах код: {code}\nКод 10 минут хүчинтэй.',
        user.email,
    )
    user.verification_digest = code_digest(user, code)
    user.verification_expires_at = now + CODE_LIFETIME
    user.verification_sent_at = now
    user.verification_attempts = 0
    user.save(update_fields=[
        'verification_digest', 'verification_expires_at',
        'verification_sent_at', 'verification_attempts',
    ])


def verify_email(*, email, code):
    with transaction.atomic():
        user = User.objects.select_for_update().filter(email__iexact=email.strip()).first()
        if (
            not user
            or user.email_verified
            or not user.is_active
            or not user.verification_expires_at
            or user.verification_expires_at <= timezone.now()
            or user.verification_attempts >= MAX_ATTEMPTS
        ):
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


# --------------------------------------------------------------------- tokens

def token_digest(token):
    return hashlib.sha256(token.encode()).hexdigest()


def create_session(user):
    now = timezone.now()
    AuthToken.objects.filter(expires_at__lte=now).delete()
    token = secrets.token_hex(32)
    AuthToken.objects.create(
        user=user,
        digest=token_digest(token),
        expires_at=now + timedelta(hours=24),
    )
    return token


# ------------------------------------------------------------- password reset

def reset_code_digest(user, code):
    return salted_hmac(
        'password-reset', f'{user.pk}:{user.password}:{code}', algorithm='sha256'
    ).hexdigest()


def request_password_reset(email):
    """Имэйл байгаа эсэхийг задруулахгүйн тулд алдааг гадагш нь шидэхгүй."""
    with transaction.atomic():
        user = User.objects.select_for_update().filter(
            email__iexact=email.strip(), is_active=True
        ).first()
        now = timezone.now()
        if not user or (user.reset_sent_at and now - user.reset_sent_at < RESEND_COOLDOWN):
            return
        code = _new_code()
        try:
            _safe_send_mail(
                'Нууц үг сэргээх код',
                f'Таны нууц үг сэргээх код: {code}\n'
                'Код 10 минут хүчинтэй. Та хүсэлт гаргаагүй бол энэ имэйлийг үл тоомсорлоно уу.',
                user.email,
            )
        except EmailSendFailed:
            return
        user.reset_digest = reset_code_digest(user, code)
        user.reset_expires_at = now + CODE_LIFETIME
        user.reset_sent_at = now
        user.reset_attempts = 0
        user.save(update_fields=[
            'reset_digest', 'reset_expires_at', 'reset_sent_at', 'reset_attempts',
        ])


def reset_password(*, email, code, password):
    """Буруу код бол False. Нууц үг сул бол ValidationError шидэнэ (view барина)."""
    with transaction.atomic():
        user = User.objects.select_for_update().filter(
            email__iexact=email.strip(), is_active=True
        ).first()
        if (
            not user
            or not user.reset_digest
            or not user.reset_expires_at
            or user.reset_expires_at <= timezone.now()
            or user.reset_attempts >= MAX_ATTEMPTS
        ):
            return False
        user.reset_attempts += 1
        user.save(update_fields=['reset_attempts'])
        if not constant_time_compare(user.reset_digest, reset_code_digest(user, code)):
            return False
        validate_password(password, user)
        user.set_password(password)
        user.reset_digest = ''
        user.reset_expires_at = None
        user.save(update_fields=['password', 'reset_digest', 'reset_expires_at'])
        AuthToken.objects.filter(user=user).delete()
        return True


# --------------------------------------------------------- register and login

def register_user(*, name, email, password):
    email = email.strip().lower()
    name = name.strip()

    existing = User.objects.filter(email__iexact=email).first()
    if existing and (existing.email_verified or not existing.is_active):
        raise EmailAlreadyRegistered

    if existing:
        # Өмнө бүртгүүлсэн боловч имэйл нь баталгаажаагүй (жишээ нь имэйл илгээж
        # чадаагүй) хэрэглэгч дахин бүртгүүлж, код дахин авч болно.
        _check_verification_cooldown(existing)
        user = existing
    else:
        user = User(username=secrets.token_hex(16), email=email)

    user.name = name
    validate_password(password, user)

    try:
        with transaction.atomic():
            user.set_password(password)
            user.save()
    except IntegrityError:
        if User.objects.filter(email__iexact=email).exists():
            raise EmailAlreadyRegistered from None
        raise

    # Имэйлийг DB transaction-ийн гадна илгээнэ: SMTP удаан байхад DB түгжигдэхгүй.
    # Илгээж чадахгүй бол EmailSendFailed шидэгдэнэ, хэрэглэгч нь баталгаажаагүй
    # хэвээр үлдэх тул дахин бүртгүүлэхэд асуудалгүй.
    send_verification(user)
    return user


def login_user(*, request, email, password):
    email = email.strip()
    existing_user = User.objects.filter(email__iexact=email).first()
    user = authenticate(
        request,
        username=existing_user.username if existing_user else email,
        password=password,
    )
    if user is None:
        return None 
    if not user.email_verified:
        raise VerificationRequired
    return user, create_session(user)