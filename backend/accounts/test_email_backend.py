import json
import re
from io import BytesIO
from smtplib import SMTPException
from unittest.mock import MagicMock, patch
from urllib.error import HTTPError, URLError

from django.core.cache import cache
from django.core.mail import send_mail
from django.test import SimpleTestCase, TestCase, override_settings

from .models import User


EMAIL_SETTINGS = dict(EMAIL_BACKEND='accounts.email_backend.ResendEmailBackend',
                      RESEND_API_KEY='test-private-key', DEFAULT_FROM_EMAIL='Donation <verify@example.com>')


def accepted_response():
    response = MagicMock()
    response.__enter__.return_value.read.return_value = b'{"id":"email-123"}'
    return response


@override_settings(**EMAIL_SETTINGS)
class ResendBackendTests(SimpleTestCase):
    @patch('accounts.email_backend.urlopen')
    def test_verification_message_uses_https_and_utf8(self, request):
        request.return_value = accepted_response()
        self.assertEqual(send_mail('Баталгаажуулалт', 'Таны код: 123456', None, ['user@example.com']), 1)
        http_request = request.call_args.args[0]
        self.assertEqual(http_request.full_url, 'https://api.resend.com/emails')
        self.assertEqual(http_request.get_header('Authorization'), 'Bearer test-private-key')
        payload = json.loads(http_request.data)
        self.assertEqual(payload['text'], 'Таны код: 123456')
        self.assertEqual(payload['from'], EMAIL_SETTINGS['DEFAULT_FROM_EMAIL'])
        self.assertEqual(payload['to'], ['user@example.com'])

    @patch('accounts.email_backend.urlopen')
    def test_http_and_network_errors_are_sanitized_delivery_failures(self, request):
        for error in (HTTPError('https://api.resend.com/emails', 403, 'private provider response', {}, BytesIO(b'private')),
                      URLError('private network details')):
            request.side_effect = error
            with self.assertRaises(SMTPException) as failure:
                send_mail('Subject', '123456', None, ['user@example.com'])
            self.assertNotIn('private', str(failure.exception))

    @override_settings(RESEND_API_KEY='')
    @patch('accounts.email_backend.urlopen')
    def test_missing_key_fails_without_network(self, request):
        with self.assertRaises(SMTPException):
            send_mail('Subject', 'Body', None, ['user@example.com'])
        request.assert_not_called()

    @patch('accounts.email_backend.urlopen', side_effect=URLError('unavailable'))
    def test_fail_silently_does_not_report_sent(self, request):
        self.assertEqual(send_mail('Subject', 'Body', None, ['user@example.com'], fail_silently=True), 0)

    @patch('accounts.email_backend.urlopen')
    def test_invalid_success_response_is_not_counted_as_sent(self, request):
        response = accepted_response()
        response.__enter__.return_value.read.return_value = b'{}'
        request.return_value = response
        with self.assertRaises(SMTPException):
            send_mail('Subject', 'Body', None, ['user@example.com'])


@override_settings(**EMAIL_SETTINGS)
class ResendRegistrationTests(TestCase):
    def setUp(self):
        cache.clear()
        self.data = {'name': 'Болд', 'email': 'resend@example.com', 'password': 'Strong!Pass483'}

    @patch('accounts.email_backend.urlopen')
    def test_code_sent_through_resend_verifies_user(self, request):
        request.return_value = accepted_response()
        response = self.client.post('/auth/register', self.data, content_type='application/json')
        self.assertEqual(response.status_code, 201)
        text = json.loads(request.call_args.args[0].data)['text']
        code = re.search(r'\b[0-9]{6}\b', text).group()
        response = self.client.post('/auth/verify-email', {'email': self.data['email'], 'code': code}, content_type='application/json')
        self.assertEqual(response.status_code, 200)
        self.assertTrue(User.objects.get(email=self.data['email']).email_verified)

    @patch('accounts.email_backend.urlopen', side_effect=URLError('unavailable'))
    def test_provider_failure_returns_503_and_rolls_back_user(self, request):
        with self.assertLogs('accounts.views', level='ERROR'):
            response = self.client.post('/auth/register', self.data, content_type='application/json')
        self.assertEqual(response.status_code, 503)
        self.assertFalse(User.objects.filter(email=self.data['email']).exists())
