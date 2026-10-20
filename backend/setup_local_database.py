"""Create the local PostgreSQL database without sharing administrator credentials."""
import getpass
import json
import os
from pathlib import Path
import secrets
import shutil
import subprocess
import sys
from datetime import datetime

import psycopg
from psycopg import sql


BASE = Path(__file__).resolve().parent
CONFIG = BASE / 'database.local.json'
LOCAL_HOST = '127.0.0.1'
LOCAL_PORT = 5432
PROJECT_TABLES = {
    'accounts_user', 'accounts_authtoken', 'accounts_user_groups',
    'accounts_user_user_permissions', 'auth_group', 'auth_group_permissions',
    'auth_permission', 'django_content_type', 'django_migrations', 'argahemjee',
    'events_eventregistration', 'events_category', 'events_eventstatus',
    'events_registrationstatus', 'events_review', 'events_notification', 'events_organization',
}


def connect_admin(password, database='postgres', **kwargs):
    return psycopg.connect(host=LOCAL_HOST, port=LOCAL_PORT, dbname=database, user='postgres',
                           password=password, connect_timeout=5, **kwargs)


def inspect_existing(password):
    with connect_admin(password, 'donation') as connection:
        rows = connection.execute("""
            SELECT c.relname, c.relkind FROM pg_class c
            JOIN pg_namespace n ON n.oid=c.relnamespace
            WHERE n.nspname='public' AND c.relkind IN ('r', 'p', 'v', 'm', 'f')
        """).fetchall()
        unexpected = [name for name, kind in rows if name not in PROJECT_TABLES or kind != 'r']
        if unexpected:
            raise RuntimeError('Unrecognized tables/views; no changes made: ' + ', '.join(unexpected))
        tables = [name for name, _ in rows]
        if 'django_migrations' in tables:
            apps = {row[0] for row in connection.execute('SELECT DISTINCT app FROM public.django_migrations')}
            if apps - {'accounts', 'events', 'auth', 'contenttypes'}:
                raise RuntimeError('This database includes other Django apps; no changes made.')
        elif tables:
            raise RuntimeError('Existing tables have no Django migration history; no changes made.')
        print('Existing project tables:', ', '.join(sorted(tables)) or '(empty database)', flush=True)
        return tables


def backup_existing(password):
    executable = shutil.which('pg_dump')
    if not executable:
        candidates = sorted(Path(os.environ.get('ProgramFiles', r'C:\Program Files')).glob(
            'PostgreSQL/*/bin/pg_dump.exe'), reverse=True)
        executable = str(candidates[0]) if candidates else None
    if not executable:
        raise RuntimeError('pg_dump not found. Install PostgreSQL tools before reusing the database.')
    directory = BASE / 'backups'
    directory.mkdir(exist_ok=True)
    destination = directory / ('donation-before-setup-' + datetime.now().strftime('%Y%m%d-%H%M%S-%f') + '.dump')
    env = os.environ.copy()
    env.update(PGPASSWORD=password, PGSSLMODE='disable', PGOPTIONS='')
    # The password only goes to the child environment, never command-line arguments.
    subprocess.run([executable, '-h', LOCAL_HOST, '-p', str(LOCAL_PORT), '-U', 'postgres',
                    '-d', 'donation', '--no-password', '-Fc', '-f', str(destination)],
                   env=env, check=True, capture_output=True, timeout=120)
    print('Backup saved:', destination.name, flush=True)
    return destination


def migrate(config):
    env = os.environ.copy()
    env.pop('DATABASE_ENGINE', None)
    env.pop('DATABASE_URL', None)
    # Explicitly override any old remote connection environment for this process.
    for key, value in config.items():
        env['DB_' + key] = str(value)
    subprocess.run([sys.executable, str(BASE / 'manage.py'), 'migrate', '--noinput'],
                   cwd=BASE, env=env, check=True)
    subprocess.run([sys.executable, str(BASE / 'manage.py'), 'check'],
                   cwd=BASE, env=env, check=True)


def main():
    print('Local PostgreSQL setup: 127.0.0.1:5432 / donation', flush=True)
    print('Enter your LOCAL postgres administrator password (input is hidden).', flush=True)
    password = getpass.getpass('PostgreSQL postgres password: ')
    with connect_admin(password, autocommit=True) as admin:
        exists = bool(admin.execute("SELECT 1 FROM pg_database WHERE datname = 'donation'").fetchone())
        tables = []
        if exists:
            tables = inspect_existing(password)
            backup_existing(password)
        role = 'donation_app'
        if admin.execute('SELECT 1 FROM pg_roles WHERE rolname = %s', (role,)).fetchone():
            role += '_' + secrets.token_hex(4)
        app_password = secrets.token_urlsafe(32)
        admin.execute(sql.SQL('CREATE ROLE {} LOGIN PASSWORD {}').format(
            sql.Identifier(role), sql.Literal(app_password)))
        try:
            if not exists:
                admin.execute(sql.SQL("CREATE DATABASE {} OWNER {} ENCODING 'UTF8'").format(
                    sql.Identifier('donation'), sql.Identifier(role)))
            else:
                with connect_admin(password, 'donation') as local:
                    local.execute(sql.SQL('GRANT CONNECT ON DATABASE donation TO {}').format(sql.Identifier(role)))
                    local.execute(sql.SQL('GRANT USAGE, CREATE ON SCHEMA public TO {}').format(sql.Identifier(role)))
                    for table in tables:
                        local.execute(sql.SQL('ALTER TABLE {} OWNER TO {}').format(
                            sql.Identifier('public', table), sql.Identifier(role)))
        except Exception:
            # Only the unused role created by this invocation is removed.
            admin.execute(sql.SQL('DROP ROLE {}').format(sql.Identifier(role)))
            raise
    config = dict(HOST=LOCAL_HOST, PORT=str(LOCAL_PORT), NAME='donation', USER=role,
                  PASSWORD=app_password, SSLMODE='disable', SCHEMA='public')
    # Preserve the old private remote settings; they are never printed or committed.
    if CONFIG.exists():
        backup_dir = BASE / 'backups'
        backup_dir.mkdir(exist_ok=True)
        backup = backup_dir / ('database-before-local-' + datetime.now().strftime('%Y%m%d-%H%M%S') + '.json')
        with backup.open('xb') as file:
            file.write(CONFIG.read_bytes())
    temporary = CONFIG.with_suffix('.json.tmp')
    temporary.write_text(json.dumps(config, indent=2) + '\n', encoding='utf-8')
    temporary.replace(CONFIG)
    migrate(config)
    with psycopg.connect(host=config['HOST'], port=int(config['PORT']), dbname='donation', user=role,
                         password=app_password, connect_timeout=5) as connection:
        count = connection.execute(
            "SELECT count(*) FROM information_schema.tables WHERE table_schema='public'"
        ).fetchone()[0]
    print(f'LOCAL_DATABASE_READY: donation; {count} tables; user={role}', flush=True)
    print('Private connection saved to backend/database.local.json. Old remote data is unchanged.')
    print('Start the backend: .\\.venv\\Scripts\\python.exe manage.py runserver 127.0.0.1:8080')
    return 0


if __name__ == '__main__':
    try:
        raise SystemExit(main())
    except RuntimeError as error:
        print(str(error))
        raise SystemExit(1)
    except (psycopg.Error, OSError, subprocess.CalledProcessError, subprocess.TimeoutExpired) as error:
        # Connection/DDL exceptions can include connection parameters; do not print them.
        print(f'Setup failed ({type(error).__name__}). Check the local PostgreSQL login/service.')
        print('If database.local.json already points to local donation, retry: python manage.py migrate')
        raise SystemExit(1)
