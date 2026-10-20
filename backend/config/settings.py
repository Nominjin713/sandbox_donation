import json
import os
from pathlib import Path

BASE_DIR = Path(__file__).resolve().parent.parent
DEBUG = os.environ.get('DJANGO_DEBUG', 'true').lower() == 'true'
SECRET_KEY = os.environ.get('DJANGO_SECRET_KEY', 'local-development-only-change-before-deployment')
if not DEBUG and SECRET_KEY == 'local-development-only-change-before-deployment':
    raise RuntimeError('Set DJANGO_SECRET_KEY for deployment.')
ALLOWED_HOSTS = os.environ.get('DJANGO_ALLOWED_HOSTS', 'localhost,127.0.0.1,10.0.2.2,testserver').split(',')
CORS_ORIGIN = os.environ.get('CORS_ORIGIN', 'http://localhost:3000')
INSTALLED_APPS = ['django.contrib.auth', 'django.contrib.contenttypes', 'accounts']
MIDDLEWARE = ['django.middleware.security.SecurityMiddleware', 'accounts.middleware.CorsMiddleware', 'django.middleware.common.CommonMiddleware']
ROOT_URLCONF = 'config.urls'
WSGI_APPLICATION = 'config.wsgi.application'
DATABASES = {'default': {'ENGINE': 'django.db.backends.sqlite3', 'NAME': BASE_DIR / 'db.sqlite3'}}
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
DATA_UPLOAD_MAX_MEMORY_SIZE = 16384
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
DEFAULT_FROM_EMAIL = email_setting('DEFAULT_FROM_EMAIL', EMAIL_HOST_USER or 'noreply@example.com')
