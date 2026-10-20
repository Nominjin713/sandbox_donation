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
