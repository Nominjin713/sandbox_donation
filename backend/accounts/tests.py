import json
import re
from unittest.mock import patch
from django.core import mail
from smtplib import SMTPException
from datetime import timedelta
from django.test import TestCase
from django.core.cache import cache
from django.utils import timezone
from .models import AuthToken, User


class AuthenticationTests(TestCase):
    def setUp(self):
        cache.clear()
        self.data = {'name': 'Болд', 'email': 'BOLD@example.com', 'password': 'Strong!Pass483'}

    def post(self, route, data):
        return self.client.post(route, json.dumps(data), content_type='application/json')

    def verify(self):
        code = re.search(r'\b[0-9]{6}\b', mail.outbox[-1].body).group()
        return self.post('/auth/verify-email', {'email': self.data['email'], 'code': code})

    def test_authentication_lifecycle(self):
        result = self.post('/auth/register', self.data)
        self.assertEqual(result.status_code, 201)
        self.assertTrue(result.json()['verification_required'])
        self.assertNotIn('token', result.json())
        self.assertEqual(self.post('/auth/login', self.data).status_code, 403)
        self.assertEqual(AuthToken.objects.count(), 0)
        body = self.verify().json()
        self.assertEqual(body['user']['email'], 'bold@example.com')
        self.assertNotIn('password', body['user'])
        self.assertTrue(User.objects.get().check_password(self.data['password']))
        self.assertEqual(self.post('/auth/register', self.data).status_code, 409)
        self.assertEqual(self.post('/auth/login', {**self.data, 'password': 'WrongPass483'}).status_code, 401)
        self.assertEqual(self.post('/auth/login', self.data).status_code, 200)
        self.assertEqual(self.client.get('/auth/me').status_code, 401)
        headers = {'HTTP_AUTHORIZATION': 'Bearer ' + body['token']}
        self.assertEqual(self.client.get('/auth/me', **headers).status_code, 200)
        self.assertEqual(self.client.post('/auth/logout', **headers).status_code, 200)
        self.assertEqual(self.client.get('/auth/me', **headers).status_code, 401)

    def test_invalid_input_and_expired_token(self):
        self.assertEqual(self.post('/auth/register', {**self.data, 'password': 'short'}).status_code, 400)
        self.assertEqual(self.post('/auth/register', {**self.data, 'email': 'invalid'}).status_code, 400)
        self.assertEqual(self.post('/auth/register', {**self.data, 'name': ''}).status_code, 400)
        self.assertEqual(self.post('/auth/register', None).status_code, 400)
        self.post('/auth/register', self.data)
        body = self.verify().json()
        AuthToken.objects.update(expires_at=timezone.now() - timedelta(seconds=1))
        self.assertEqual(self.client.get('/auth/me', HTTP_AUTHORIZATION='Bearer ' + body['token']).status_code, 401)

    def test_rate_limit(self):
        for _ in range(20):
            self.post('/auth/login', {})
        self.assertEqual(self.post('/auth/login', {}).status_code, 429)

    def test_wrong_expired_and_reused_codes(self):
        self.post('/auth/register', self.data)
        code = re.search(r'\b[0-9]{6}\b', mail.outbox[-1].body).group()
        wrong = '000000' if code != '000000' else '111111'
        for _ in range(5):
            self.assertEqual(self.post('/auth/verify-email', {'email': self.data['email'], 'code': wrong}).status_code, 400)
        self.assertEqual(self.verify().status_code, 400)
        User.objects.update(verification_attempts=0, verification_expires_at=timezone.now() - timedelta(seconds=1))
        self.assertEqual(self.verify().status_code, 400)
        User.objects.update(verification_expires_at=timezone.now() + timedelta(minutes=1))
        self.assertEqual(self.verify().status_code, 200)
        self.assertEqual(self.verify().status_code, 400)

    def test_resend_cooldown_and_credentials(self):
        self.post('/auth/register', self.data)
        self.assertEqual(self.post('/auth/resend-verification', self.data).status_code, 429)
        self.assertEqual(self.post('/auth/resend-verification', {**self.data, 'password': 'WrongPass483'}).status_code, 401)
        User.objects.update(verification_sent_at=timezone.now() - timedelta(minutes=2))
        self.assertEqual(self.post('/auth/resend-verification', self.data).status_code, 200)
        self.assertEqual(len(mail.outbox), 2)
        self.assertEqual(self.verify().status_code, 200)

    def test_resend_replaces_code_and_unverified_sessions_are_rejected(self):
        from .services import create_session
        with patch('accounts.services.secrets.randbelow', return_value=123456):
            self.post('/auth/register', self.data)
        token = create_session(User.objects.get())
        self.assertEqual(self.client.get('/auth/me', HTTP_AUTHORIZATION='Bearer ' + token).status_code, 401)
        User.objects.update(verification_sent_at=timezone.now() - timedelta(minutes=2))
        with patch('accounts.services.secrets.randbelow', return_value=654321):
            self.assertEqual(self.post('/auth/resend-verification', self.data).status_code, 200)
        self.assertEqual(self.post('/auth/verify-email', {'email': self.data['email'], 'code': '123456'}).status_code, 400)
        self.assertEqual(self.verify().status_code, 200)

    @patch('accounts.services.send_mail', side_effect=SMTPException('unavailable'))
    def test_delivery_failure_rolls_back_registration(self, mocked):
        self.assertEqual(self.post('/auth/register', self.data).status_code, 503)
        self.assertFalse(User.objects.exists())
        self.assertFalse(AuthToken.objects.exists())

    def test_invalid_verification_payloads(self):
        for data in [None, [], {}, {'email': 'invalid', 'code': '123456'}, {'email': self.data['email'], 'code': 123456}]:
            self.assertEqual(self.post('/auth/verify-email', data).status_code, 400)

    def test_cors(self):
        response = self.client.options('/auth/login', HTTP_ORIGIN='http://localhost:3000')
        self.assertEqual(response.status_code, 204)
        self.assertEqual(response['Access-Control-Allow-Origin'], 'http://localhost:3000')
