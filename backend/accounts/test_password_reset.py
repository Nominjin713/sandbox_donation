import json
import re
from datetime import timedelta
from unittest.mock import patch

from django.core import mail
from django.core.cache import cache
from django.test import TestCase
from django.utils import timezone

from .models import AuthToken, User
from .services import create_session


class PasswordResetTests(TestCase):
    def setUp(self):
        cache.clear()
        self.user = User.objects.create_user(username='reset-user', email='reset@example.com', password='Original!Pass123', email_verified=True)

    def post(self, route, data):
        return self.client.post('/auth/' + route, json.dumps(data), content_type='application/json')

    def request_code(self):
        self.assertEqual(self.post('forgot-password', {'email': ' RESET@example.com '}).status_code, 200)
        return re.search(r'\b[0-9]{6}\b', mail.outbox[-1].body).group()

    def reset(self, code, password='Replacement!Pass456'):
        return self.post('reset-password', {'email': self.user.email, 'code': code, 'password': password})

    def test_reset_revokes_sessions_and_code_cannot_be_reused(self):
        token = create_session(self.user)
        code = self.request_code()
        self.user.refresh_from_db()
        self.assertNotEqual(self.user.reset_digest, code)
        self.assertEqual(self.reset(code).status_code, 200)
        self.user.refresh_from_db()
        self.assertTrue(self.user.check_password('Replacement!Pass456'))
        self.assertFalse(AuthToken.objects.exists())
        self.assertEqual(self.client.get('/auth/me', HTTP_AUTHORIZATION='Bearer ' + token).status_code, 401)
        self.assertEqual(self.reset(code).status_code, 400)
        self.assertEqual(self.post('login', {'email': self.user.email, 'password': 'Replacement!Pass456'}).status_code, 200)

    def test_unknown_email_and_cooldown(self):
        result = self.post('forgot-password', {'email': 'unknown@example.com'})
        self.request_code()
        self.assertEqual(result.json(), self.post('forgot-password', {'email': self.user.email}).json())
        self.assertEqual(len(mail.outbox), 1)

    def test_wrong_expired_and_replaced_codes(self):
        with patch('accounts.services.secrets.randbelow', return_value=123456):
            self.request_code()
        for _ in range(5):
            self.assertEqual(self.reset('000000').status_code, 400)
        self.assertEqual(self.reset('123456').status_code, 400)
        User.objects.update(reset_sent_at=timezone.now() - timedelta(minutes=2))
        with patch('accounts.services.secrets.randbelow', return_value=654321):
            self.request_code()
        self.assertEqual(self.reset('123456').status_code, 400)
        User.objects.update(reset_expires_at=timezone.now() - timedelta(seconds=1))
        self.assertEqual(self.reset('654321').status_code, 400)

    def test_bad_payloads_and_weak_password(self):
        for payload in [None, [], {}, {'email': 'invalid'}]:
            self.assertEqual(self.post('forgot-password', payload).status_code, 400)
        code = self.request_code()
        self.assertEqual(self.reset(code, '12345678').status_code, 400)
        self.assertEqual(self.reset(code).status_code, 200)
