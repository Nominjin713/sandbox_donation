import json
import os
from pathlib import Path

BASE_DIR = Path(__file__).resolve().parent.parent
DEBUG = os.environ.get('DJANGO_DEBUG', 'true').lower() == 'true'
SECRET_KEY = os.environ.get('DJANGO_SECRET_KEY', 'local-development-only-change-before-deployment')
if not DEBUG and SECRET_KEY == 'local-development-only-change-before-deployment':
    raise RuntimeError('Set DJANGO_SECRET_KEY for deployment.')
default_hosts = os.environ.get('KOYEB_PUBLIC_DOMAIN', 'localhost,127.0.0.1,10.0.2.2,testserver')
if os.environ.get('RENDER_EXTERNAL_HOSTNAME'):
    default_hosts += ',' + os.environ['RENDER_EXTERNAL_HOSTNAME']
ALLOWED_HOSTS = [host.strip() for host in os.environ.get('DJANGO_ALLOWED_HOSTS', default_hosts).split(',') if host.strip()]
CORS_ORIGIN = os.environ.get('CORS_ORIGIN', 'http://localhost:3000')
CORS_ALLOWED_ORIGINS = [origin.strip() for origin in os.environ.get('CORS_ALLOWED_ORIGINS', CORS_ORIGIN).split(',') if origin.strip()]
INSTALLED_APPS = ['django.contrib.auth', 'django.contrib.contenttypes', 'accounts','events']
MIDDLEWARE = ['django.middleware.security.SecurityMiddleware', 'accounts.middleware.CorsMiddleware', 'django.middleware.common.CommonMiddleware']
ROOT_URLCONF = 'config.urls'
WSGI_APPLICATION = 'config.wsgi.application'
from .database import database_settings
DATABASES = {'default': database_settings(BASE_DIR)}
AUTH_USER_MODEL = 'accounts.User'
AUTH_PASSWORD_VALIDATORS = [
    {'NAME': 'django.contrib.auth.password_validation.UserAttributeSimilarityValidator'},
    {'NAME': 'django.contrib.auth.password_validation.MinimumLengthValidator'},
    {'NAME': 'django.contrib.auth.password_validation.CommonPasswordValidator'},
    {'NAME': 'django.contrib.auth.password_validation.NumericPasswordValidator'},
]
LANGUAGE_CODE = 'mn'
TIME_ZONE = 'Asia/Ulaanbaatar'
USE_I18N = True
USE_TZ = True
DEFAULT_AUTO_FIELD = 'django.db.models.BigAutoField'
DATA_UPLOAD_MAX_MEMORY_SIZE = 10 * 1024 * 1024  # ЗАССАН: 16KB байсныг 10MB болгов
MEDIA_URL = '/media/'                           # ШИНЭ
MEDIA_ROOT = BASE_DIR / 'media'                 # ШИНЭ
SECURE_CONTENT_TYPE_NOSNIFF = True
email_config_path = BASE_DIR / 'email.local.json'
email_config = json.loads(email_config_path.read_text(encoding='utf-8')) if email_config_path.exists() else {}


def email_setting(name, default=''):
    return os.environ.get(name, email_config.get(name, default))


EMAIL_BACKEND = email_setting('EMAIL_BACKEND', 'django.core.mail.backends.console.EmailBackend' if DEBUG else 'django.core.mail.backends.smtp.EmailBackend')
EMAIL_HOST = email_setting('EMAIL_HOST', 'localhost')
EMAIL_PORT = int(email_setting('EMAIL_PORT', '587'))
EMAIL_HOST_USER = email_setting('EMAIL_HOST_USER')
EMAIL_HOST_PASSWORD = email_setting('EMAIL_HOST_PASSWORD')
if EMAIL_HOST == 'smtp.gmail.com':
    EMAIL_HOST_PASSWORD = ''.join(EMAIL_HOST_PASSWORD.split())
EMAIL_USE_TLS = str(email_setting('EMAIL_USE_TLS', 'true')).lower() == 'true'
EMAIL_TIMEOUT = 10
RESEND_API_KEY = email_setting('RESEND_API_KEY')
GMAIL_CLIENT_ID = email_setting('GMAIL_CLIENT_ID')
GMAIL_CLIENT_SECRET = email_setting('GMAIL_CLIENT_SECRET')
GMAIL_REFRESH_TOKEN = email_setting('GMAIL_REFRESH_TOKEN')
DEFAULT_FROM_EMAIL = email_setting('DEFAULT_FROM_EMAIL', EMAIL_HOST_USER or 'noreply@example.com')