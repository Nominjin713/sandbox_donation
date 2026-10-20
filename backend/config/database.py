"""PostgreSQL settings from the hosting environment or private local config."""
import json
import os
import re

from django.core.exceptions import ImproperlyConfigured
from psycopg import ProgrammingError
from psycopg.conninfo import conninfo_to_dict


def database_url_settings(url):
    try:
        if not url.startswith(('postgresql://', 'postgres://')):
            raise ValueError
        parameters = conninfo_to_dict(url)
        if not all(parameters.get(key) for key in ('host', 'dbname', 'user')):
            raise ValueError
        if not 1 <= int(parameters.get('port', '5432')) <= 65535:
            raise ValueError
    except (ValueError, ProgrammingError):
        # Parser errors can contain the full URL/password. Keep them out of logs.
        raise ImproperlyConfigured('DATABASE_URL must be a valid PostgreSQL connection URL.') from None
    return {
        'ENGINE': 'django.db.backends.postgresql',
        'NAME': parameters['dbname'], 'USER': parameters['user'],
        'PASSWORD': parameters.get('password', ''), 'HOST': parameters['host'],
        'PORT': parameters.get('port', '5432'),
        'CONN_MAX_AGE': 60, 'CONN_HEALTH_CHECKS': True,
        'OPTIONS': {'connect_timeout': 10, 'sslmode': parameters.get('sslmode', 'require')},
    }


def database_settings(base_dir):
    if os.environ.get('DATABASE_ENGINE') == 'sqlite':
        return {'ENGINE': 'django.db.backends.sqlite3', 'NAME': os.environ.get('SQLITE_PATH', base_dir / 'db.sqlite3')}
    if os.environ.get('DATABASE_URL'):
        return database_url_settings(os.environ['DATABASE_URL'])
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
