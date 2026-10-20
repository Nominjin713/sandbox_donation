import base64
from email import policy
from email.parser import BytesParser
from io import BytesIO
import json
from pathlib import Path
from smtplib import SMTPException
from tempfile import TemporaryDirectory
from types import SimpleNamespace
from unittest.mock import MagicMock, patch
from urllib.error import HTTPError, URLError

from django.core.cache import cache
from django.core.mail import EmailMessage, send_mail
from django.test import SimpleTestCase, TestCase, override_settings

from .models import User
from setup_gmail_api import export_credentials


SETTINGS = dict(EMAIL_BACKEND='accounts.gmail_backend.GmailApiEmailBackend',
                GMAIL_CLIENT_ID='test-client', GMAIL_CLIENT_SECRET='test-secret',
                GMAIL_REFRESH_TOKEN='test-refresh', DEFAULT_FROM_EMAIL='sender@gmail.com')


def response(data):
    result = MagicMock()
    result.__enter__.return_value.read.return_value = json.dumps(data).encode()
    return result


def token():
    return response({'access_token': 'test-access', 'expires_in': 3600})


@override_settings(**SETTINGS)
class GmailBackendTests(SimpleTestCase):
    def setUp(self):
        reset = patch('accounts.gmail_backend._token_cache', None)
        reset.start()
        self.addCleanup(reset.stop)

    @patch('accounts.gmail_backend.urlopen')
    def test_refresh_and_utf8_mime_delivery_and_cached_access(self, request):
        request.side_effect = [token(), response({'id': 'mail-1'}), response({'id': 'mail-2'})]
        for _ in range(2):
            self.assertEqual(send_mail('Баталгаажуулалт', 'Код: 123456', None, ['other@example.com']), 1)
        self.assertEqual(request.call_count, 3)
        refresh = request.call_args_list[0].args[0]
        self.assertEqual(refresh.full_url, 'https://oauth2.googleapis.com/token')
        self.assertIn(b'grant_type=refresh_token', refresh.data)
        delivery = request.call_args_list[1].args[0]
        self.assertEqual(delivery.full_url, 'https://gmail.googleapis.com/gmail/v1/users/me/messages/send')
        self.assertEqual(delivery.get_header('Authorization'), 'Bearer test-access')
        mime = BytesParser(policy=policy.default).parsebytes(base64.urlsafe_b64decode(json.loads(delivery.data)['raw']))
        self.assertEqual(str(mime['Subject']), 'Баталгаажуулалт')
        self.assertEqual(str(mime['To']), 'other@example.com')
        self.assertEqual(str(mime['From']), 'sender@gmail.com')
        self.assertEqual(mime.get_content().strip(), 'Код: 123456')

    @patch('accounts.gmail_backend.monotonic', return_value=100)
    @patch('accounts.gmail_backend.urlopen')
    def test_expired_cached_access_token_is_refreshed(self, request, clock):
        request.side_effect = [token(), response({'id': 'mail-1'}), token(), response({'id': 'mail-2'})]
        send_mail('Subject', 'Body', None, ['other@example.com'])
        clock.return_value = 4000
        send_mail('Subject', 'Body', None, ['other@example.com'])
        self.assertEqual(request.call_count, 4)

    @override_settings(GMAIL_REFRESH_TOKEN='')
    @patch('accounts.gmail_backend.urlopen')
    def test_missing_refresh_token_fails_without_network(self, request):
        with self.assertRaises(SMTPException):
            send_mail('Subject', 'Body', None, ['other@example.com'])
        request.assert_not_called()

    @patch('accounts.gmail_backend.urlopen')
    def test_delivery_error_is_sanitized_and_clears_cached_token(self, request):
        error = HTTPError('https://gmail.googleapis.com/', 403, 'private-token', {}, BytesIO(b'private-token'))
        request.side_effect = [token(), error]
        with self.assertRaises(SMTPException) as failure:
            send_mail('Subject', 'Body', None, ['other@example.com'])
        self.assertNotIn('private-token', str(failure.exception))
        from . import gmail_backend
        self.assertIsNone(gmail_backend._token_cache)

    @patch('accounts.gmail_backend.urlopen', side_effect=URLError('unavailable'))
    def test_fail_silently_returns_zero(self, request):
        self.assertEqual(send_mail('Subject', 'Body', None, ['other@example.com'], fail_silently=True), 0)

    @patch('accounts.gmail_backend.urlopen')
    def test_incomplete_token_and_delivery_responses_are_rejected(self, request):
        for replies in ([response({})], [token(), response({})], [response([])]):
            request.side_effect = replies
            with self.assertRaises(SMTPException):
                send_mail('Subject', 'Body', None, ['other@example.com'])

    @patch('accounts.gmail_backend.urlopen')
    def test_hidden_recipient_is_rejected_before_network(self, request):
        with self.assertRaises(SMTPException):
            EmailMessage('Subject', 'Body', to=['other@example.com'], bcc=['hidden@example.com']).send()
        request.assert_not_called()


@override_settings(**SETTINGS)
class GmailRegistrationTests(TestCase):
    def setUp(self):
        cache.clear()
        reset = patch('accounts.gmail_backend._token_cache', None)
        reset.start()
        self.addCleanup(reset.stop)
        self.data = {'name': 'Gmail test', 'email': 'gmail-api@example.com', 'password': 'Strong!Pass483'}

    @patch('accounts.gmail_backend.urlopen')
    def test_registration_sends_code_and_verifies(self, request):
        import re
        request.side_effect = [token(), response({'id': 'mail-1'})]
        result = self.client.post('/auth/register', self.data, content_type='application/json')
        self.assertEqual(result.status_code, 201)
        raw = json.loads(request.call_args.args[0].data)['raw']
        mime = BytesParser(policy=policy.default).parsebytes(base64.urlsafe_b64decode(raw))
        code = re.search(r'\b[0-9]{6}\b', mime.get_content()).group()
        result = self.client.post('/auth/verify-email', {'email': self.data['email'], 'code': code}, content_type='application/json')
        self.assertEqual(result.status_code, 200)
        self.assertTrue(User.objects.get(email=self.data['email']).email_verified)

    @patch('accounts.gmail_backend.urlopen', side_effect=URLError('unavailable'))
    def test_google_failure_returns_503_and_rolls_back_registration(self, request):
        with self.assertLogs('accounts.views', level='ERROR'):
            result = self.client.post('/auth/register', self.data, content_type='application/json')
        self.assertEqual(result.status_code, 503)
        self.assertFalse(User.objects.filter(email=self.data['email']).exists())


class GmailExportTests(SimpleTestCase):
    def test_private_export_has_only_render_variables_and_preserves_previous_file(self):
        credentials = SimpleNamespace(client_id='client', client_secret='secret', refresh_token='refresh')
        with TemporaryDirectory() as directory, patch('setup_gmail_api.BASE', Path(directory)):
            path = export_credentials(credentials, 'sender@gmail.com')
            first = path.read_bytes()
            credentials.refresh_token = 'new-refresh'
            export_credentials(credentials, 'sender@gmail.com')
            self.assertEqual(list((Path(directory) / 'backups').glob('*.env'))[0].read_bytes(), first)
            self.assertIn('GMAIL_REFRESH_TOKEN=new-refresh', path.read_text())
            self.assertNotIn('access_token', path.read_text())

    def test_missing_refresh_token_and_newline_injection_do_not_create_export(self):
        with TemporaryDirectory() as directory, patch('setup_gmail_api.BASE', Path(directory)):
            for refresh in ('', 'refresh\nUNEXPECTED=value'):
                credentials = SimpleNamespace(client_id='client', client_secret='secret', refresh_token=refresh)
                with self.assertRaises(ValueError):
                    export_credentials(credentials, 'sender@gmail.com')
            self.assertFalse((Path(directory) / 'gmail.render.env').exists())
