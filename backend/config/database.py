"""PostgreSQL settings from the hosting environment or private local config."""
import json
import os
import re

from django.core.exceptions import ImproperlyConfigured


def database_settings(base_dir):
    if os.environ.get('DATABASE_ENGINE') == 'sqlite':
        return {'ENGINE': 'django.db.backends.sqlite3', 'NAME': os.environ.get('SQLITE_PATH', base_dir / 'db.sqlite3')}
    path = base_dir / 'database.local.json'
    local = json.loads(path.read_text(encoding='utf-8-sig')) if path.exists() else {}
    def value(name, default=''):
        return os.environ.get(f'DB_{name}', local.get(name, default))
    host = value('HOST', '127.0.0.1')
    options = {'connect_timeout': 10}
    sslmode = value('SSLMODE', 'require' if host.endswith('.supabase.com') else '')
    if sslmode:
        options['sslmode'] = sslmode
    schema = value('SCHEMA')
    if schema:
        if not re.fullmatch(r'[a-z_][a-z0-9_]*', schema):
            raise ImproperlyConfigured('DB_SCHEMA must contain only lowercase letters, numbers and underscores.')
        options['options'] = f'-c search_path={schema},public'
    return {
        'ENGINE': 'django.db.backends.postgresql',
        'NAME': value('NAME', 'donation'), 'USER': value('USER', 'donation_user'),
        'PASSWORD': value('PASSWORD'), 'HOST': host, 'PORT': value('PORT', '5432'),
        'OPTIONS': options,
    }
