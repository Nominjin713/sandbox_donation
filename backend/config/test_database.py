import json
import os
from pathlib import Path
from tempfile import TemporaryDirectory
from unittest import TestCase
from unittest.mock import patch

from django.core.exceptions import ImproperlyConfigured

from .database import database_settings


class DatabaseSettingsTests(TestCase):
    def setUp(self):
        environment = patch.dict(os.environ, {}, clear=True)
        environment.start()
        self.addCleanup(environment.stop)
        directory = TemporaryDirectory()
        self.addCleanup(directory.cleanup)
        self.base = Path(directory.name)

    def test_hosting_environment_overrides_private_local_settings(self):
        (self.base / 'database.local.json').write_text(json.dumps({
            'USER': 'local_user', 'PASSWORD': 'local-password', 'NAME': 'local_db',
        }), encoding='utf-8')
        os.environ.update(DB_HOST='region.pooler.supabase.com', DB_SCHEMA='donation',
                          DB_USER='remote_user', DB_PASSWORD='remote-password')
        config = database_settings(self.base)
        self.assertEqual(config['USER'], 'remote_user')
        self.assertEqual(config['PASSWORD'], 'remote-password')
        self.assertEqual(config['OPTIONS']['sslmode'], 'require')
        self.assertEqual(config['OPTIONS']['options'], '-c search_path=donation,public')

    def test_invalid_schema_is_rejected(self):
        os.environ['DB_SCHEMA'] = 'donation; invalid'
        with self.assertRaises(ImproperlyConfigured):
            database_settings(self.base)

    def test_sqlite_override_bypasses_postgresql_credentials(self):
        os.environ['DATABASE_ENGINE'] = 'sqlite'
        config = database_settings(self.base)
        self.assertEqual(config['ENGINE'], 'django.db.backends.sqlite3')
        self.assertEqual(config['NAME'], self.base / 'db.sqlite3')

    def test_render_url_overrides_local_database_and_decodes_password(self):
        (self.base / 'database.local.json').write_text(json.dumps({'HOST': '127.0.0.1', 'SCHEMA': 'old_schema'}))
        os.environ['DATABASE_URL'] = 'postgresql://app:p%40ss%3Aword@render.internal:5432/donation'
        config = database_settings(self.base)
        self.assertEqual(config['HOST'], 'render.internal')
        self.assertEqual(config['NAME'], 'donation')
        self.assertEqual(config['PASSWORD'], 'p@ss:word')
        self.assertEqual(config['OPTIONS']['sslmode'], 'require')
        self.assertNotIn('options', config['OPTIONS'])

    def test_invalid_render_url_does_not_expose_credentials(self):
        for url in ('mysql://app:private@host/db', 'postgresql://app:private@host:bad/db', 'postgresql:///db'):
            os.environ['DATABASE_URL'] = url
            with self.subTest(url_scheme=url.split(':')[0]):
                with self.assertRaises(ImproperlyConfigured) as failure:
                    database_settings(self.base)
                self.assertNotIn('private', str(failure.exception))
