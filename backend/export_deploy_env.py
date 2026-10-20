"""Prepare a Git-ignored environment file using the working local settings."""
import json
import os
from pathlib import Path
import secrets

os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'config.settings')


def main():
    from django.conf import settings

    output = Path(settings.BASE_DIR) / 'deploy.env'
    existing = {}
    if output.exists():
        for line in output.read_text(encoding='utf-8').splitlines():
            if line and not line.startswith('#'):
                key, value = line.split('=', 1)
                existing[key] = json.loads(value)
    db = settings.DATABASES['default']
    if db['ENGINE'] != 'django.db.backends.postgresql' or not db.get('PASSWORD'):
        raise RuntimeError('Configure the working PostgreSQL connection before exporting.')
    local_path = Path(settings.BASE_DIR) / 'database.local.json'
    local = json.loads(local_path.read_text(encoding='utf-8-sig')) if local_path.exists() else {}
    values = {
        'DJANGO_DEBUG': 'false',
        'DJANGO_SECRET_KEY': existing.get('DJANGO_SECRET_KEY') or secrets.token_urlsafe(64),
        'CORS_ALLOWED_ORIGINS': existing.get('CORS_ALLOWED_ORIGINS', 'http://localhost:3000,http://127.0.0.1:3000'),
        'DB_NAME': db['NAME'], 'DB_USER': db['USER'], 'DB_PASSWORD': db['PASSWORD'],
        'DB_HOST': db['HOST'], 'DB_PORT': str(db['PORT']),
        'DB_SSLMODE': db.get('OPTIONS', {}).get('sslmode', 'require'),
        'DB_SCHEMA': os.environ.get('DB_SCHEMA', local.get('SCHEMA', '')),
        'EMAIL_BACKEND': 'django.core.mail.backends.smtp.EmailBackend',
        'EMAIL_HOST': settings.EMAIL_HOST, 'EMAIL_PORT': str(settings.EMAIL_PORT),
        'EMAIL_HOST_USER': settings.EMAIL_HOST_USER,
        'EMAIL_HOST_PASSWORD': settings.EMAIL_HOST_PASSWORD,
        'EMAIL_USE_TLS': str(settings.EMAIL_USE_TLS).lower(),
        'DEFAULT_FROM_EMAIL': settings.DEFAULT_FROM_EMAIL,
    }
    if not values['EMAIL_HOST_USER'] or not values['EMAIL_HOST_PASSWORD']:
        raise RuntimeError('Configure the working SMTP account before exporting.')
    output.write_text('# Private hosting environment variables. Do not commit.\n' +
                      ''.join(f'{key}={json.dumps(str(value))}\n' for key, value in values.items()),
                      encoding='utf-8')
    print('Created deploy.env with database and email settings. Values were not printed.')


if __name__ == '__main__':
    main()
