import json
import logging
from smtplib import SMTPException
from functools import wraps
from django.core.cache import cache
from django.core.exceptions import ValidationError, RequestDataTooBig
from django.core.validators import validate_email
from django.http import JsonResponse
from .models import User
from .authentication import get_session as session
from django.utils import timezone
from django.utils.dateparse import parse_date
from django.db import transaction
from .services import (
    EmailAlreadyRegistered,
    EmailSendFailed,
    VerificationCooldown,
    VerificationRequired,
    register_user,
    login_user,
    send_verification,
    verify_email,
)
from .services import request_password_reset, reset_password

logger = logging.getLogger(__name__)

# Имэйл илгээхэд гарч болох бүх алдаа
MAIL_ERRORS = (EmailSendFailed, SMTPException, OSError)
MAIL_FAILED_MESSAGE = 'Имэйл илгээж чадсангүй. Түр хүлээгээд дахин оролдоно уу.'


def error(message, status=400):
    return JsonResponse({'message': message}, status=status)


def user_data(user):
    return {
        'id': user.pk,
        'name': user.name,
        'email': user.email,
        'phone': user.phone or '',
        'birth_date': user.birth_date.isoformat() if user.birth_date else '',
    }


def endpoint(method, limited=False):
    def decorate(view):
        @wraps(view)
        def wrapped(request):
            if request.method != method:
                return error('Буруу хүсэлтийн төрөл.', 405)
            if limited:
                key = 'auth-attempt:' + request.META.get('REMOTE_ADDR', '')
                cache.add(key, 0, timeout=60)
                if cache.incr(key) > 20:
                    return error('Түр хүлээгээд дахин оролдоно уу.', 429)
            return view(request)
        return wrapped
    return decorate


def credentials(request):
    try:
        body = json.loads(request.body)
    except (ValueError, UnicodeDecodeError, RequestDataTooBig):
        raise ValueError('Буруу хүсэлт.')
    if not isinstance(body, dict):
        raise ValueError('Буруу хүсэлт.')
    email, password = body.get('email'), body.get('password')
    if not isinstance(email, str) or not isinstance(password, str):
        raise ValueError('Имэйл болон нууц үг оруулна уу.')
    email = email.strip().lower()
    try:
        validate_email(email)
    except ValidationError:
        raise ValueError('Зөв имэйл оруулна уу.')
    if len(email) > 254 or not 8 <= len(password) <= 128:
        raise ValueError('Зөв имэйл болон 8–128 тэмдэгттэй нууц үг оруулна уу.')
    return body, email, password


@endpoint('GET')
def health(request):
    return JsonResponse({'status': 'ok'})


@endpoint('POST', limited=True)
def forgot_password(request):
    try:
        body = json.loads(request.body)
        email = body.get('email')
        if not isinstance(email, str) or len(email.strip()) > 254:
            raise ValueError
        validate_email(email.strip())
    except (ValueError, AttributeError, UnicodeDecodeError, ValidationError, RequestDataTooBig):
        return error('Зөв имэйл оруулна уу.')
    try:
        request_password_reset(email.strip().lower())
    except MAIL_ERRORS:
        logger.exception('Password reset email delivery failed')
        return error(MAIL_FAILED_MESSAGE, 503)
    return JsonResponse({'message': 'Бүртгэлтэй имэйл бол сэргээх код илгээгдэнэ. Имэйлээ шалгана уу.'})


@endpoint('POST', limited=True)
def reset_password_view(request):
    try:
        body, email, password = credentials(request)
        code = body.get('code')
        if not isinstance(code, str) or len(code) != 6 or not code.isascii() or not code.isdigit():
            return error('6 оронтой код оруулна уу.')
        success = reset_password(email=email, code=code, password=password)
    except ValueError as exc:
        return error(str(exc))
    except ValidationError as exc:
        return error(' '.join(exc.messages))
    if not success:
        return error('Код буруу эсвэл хугацаа дууссан байна. Шинэ код авна уу.')
    return JsonResponse({'message': 'Нууц үг шинэчлэгдлээ. Шинэ нууц үгээрээ нэвтэрнэ үү.'})


@endpoint('POST', limited=True)
def register(request):
    try:
        body, email, password = credentials(request)
    except ValueError as exc:
        return error(str(exc))
    name = body.get('name')
    if not isinstance(name, str) or not 1 <= len(name.strip()) <= 100:
        return error('Нэрээ оруулна уу (100 хүртэл тэмдэгт).')
    try:
        register_user(name=name, email=email, password=password)
    except EmailAlreadyRegistered:
        return error('Энэ имэйл бүртгэлтэй байна.', 409)
    except VerificationCooldown as exc:
        return error(str(exc), 429)
    except ValidationError as exc:
        return error(' '.join(exc.messages))
    except MAIL_ERRORS:
        logger.exception('Verification email delivery failed')
        return error(MAIL_FAILED_MESSAGE, 503)
    return JsonResponse(
        {'verification_required': True, 'message': 'Имэйлд ирсэн 6 оронтой кодыг оруулна уу.'},
        status=201,
    )


@endpoint('POST', limited=True)
def login(request):
    try:
        _, email, password = credentials(request)
    except ValueError as exc:
        return error(str(exc))
    try:
        result = login_user(request=request, email=email, password=password)
    except VerificationRequired:
        return JsonResponse({'verification_required': True, 'message': 'Имэйлээ баталгаажуулна уу.'}, status=403)
    if result is None:
        return error('Имэйл эсвэл нууц үг буруу байна.', 401)
    user, token = result
    return JsonResponse({'token': token, 'user': user_data(user)})


@endpoint('GET')
def me(request):
    token = session(request)
    return JsonResponse({'user': user_data(token.user)}) if token else error('Дахин нэвтэрнэ үү.', 401)


@endpoint('POST')
def logout(request):
    token = session(request)
    if token:
        token.delete()
    return JsonResponse({'message': 'Амжилттай гарлаа.'})


@endpoint('POST', limited=True)
def verify(request):
    try:
        body = json.loads(request.body)
        email, code = body.get('email'), body.get('code')
        if not isinstance(email, str) or not isinstance(code, str) or len(code) != 6 or not code.isascii() or not code.isdigit():
            raise ValueError
        validate_email(email.strip())
    except (ValueError, AttributeError, UnicodeDecodeError, ValidationError, RequestDataTooBig):
        return error('Имэйл болон 6 оронтой код оруулна уу.')
    result = verify_email(email=email.strip().lower(), code=code)
    if result is None:
        return error('Код буруу эсвэл хугацаа дууссан байна. Шинэ код авна уу.')
    user, token = result
    return JsonResponse({'token': token, 'user': user_data(user)})


@endpoint('POST', limited=True)
def resend_verification(request):
    try:
        _, email, password = credentials(request)
    except ValueError as exc:
        return error(str(exc))
    try:
        with transaction.atomic():
            user = User.objects.select_for_update().filter(
                email__iexact=email, is_active=True, email_verified=False
            ).first()
            if not user or not user.check_password(password):
                return error('Имэйл эсвэл нууц үг буруу байна.', 401)
            send_verification(user)
    except VerificationCooldown as exc:
        return error(str(exc), 429)
    except MAIL_ERRORS:
        logger.exception('Verification email delivery failed')
        return error(MAIL_FAILED_MESSAGE, 503)
    return JsonResponse({'message': 'Шинэ код илгээлээ.'})


# Хэрэглэгч өөрийн профайлаа засах
PROFILE_FIELDS = ('name', 'phone', 'birth_date')


@endpoint('POST')
def update_profile(request):
    token = session(request)
    if token is None:
        return error('Дахин нэвтэрнэ үү.', 401)
    try:
        body = json.loads(request.body)
    except (ValueError, UnicodeDecodeError, RequestDataTooBig):
        return error('Зөв JSON хүсэлт илгээнэ үү.')
    if not isinstance(body, dict):
        return error('JSON object илгээнэ үү.')

    unknown = set(body) - set(PROFILE_FIELDS)
    if unknown:
        return JsonResponse(
            {
                'message': 'Танигдахгүй талбар байна.',
                'errors': {field: ['Танигдахгүй талбар.'] for field in sorted(unknown)},
            },
            status=400,
        )

    user = token.user
    errors = {}

    if 'name' in body:
        name = body['name']
        if not isinstance(name, str) or not 1 <= len(name.strip()) <= 100:
            errors['name'] = ['Нэрээ 1–100 тэмдэгтээр бичнэ үү.']
        else:
            user.name = name.strip()

    if 'phone' in body:
        phone = body['phone']
        if not isinstance(phone, str) or len(phone.strip()) > 30:
            errors['phone'] = ['Утасны дугаар 30 тэмдэгтээс хэтрэхгүй байна.']
        else:
            phone = phone.strip()
            if phone and not all(char.isdigit() or char in '+-() ' for char in phone):
                errors['phone'] = ['Утасны дугаарт тоо болон + - ( ) л орно.']
            else:
                user.phone = phone

    if 'birth_date' in body:
        raw = body['birth_date']
        if raw in (None, ''):
            user.birth_date = None
        elif not isinstance(raw, str):
            errors['birth_date'] = ['Төрсөн огноог YYYY-MM-DD хэлбэрээр оруулна уу.']
        else:
            parsed = parse_date(raw.strip())
            if parsed is None:
                errors['birth_date'] = ['Төрсөн огноог YYYY-MM-DD хэлбэрээр оруулна уу.']
            elif parsed > timezone.localdate():
                errors['birth_date'] = ['Төрсөн огноо ирээдүйд байж болохгүй.']
            else:
                user.birth_date = parsed

    if errors:
        return JsonResponse({'message': 'Мэдээллээ шалгана уу.', 'errors': errors}, status=400)

    user.save(update_fields=['name', 'phone', 'birth_date'])
    return JsonResponse({'message': 'Профайлыг шинэчиллээ.', 'user': user_data(user)})