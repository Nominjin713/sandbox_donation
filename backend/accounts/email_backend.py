"""Send verification emails over HTTPS on hosts that block SMTP."""
import json
from smtplib import SMTPException
from urllib.error import HTTPError, URLError
from urllib.request import Request, urlopen

from django.conf import settings
from django.core.mail.backends.base import BaseEmailBackend


class ResendEmailBackend(BaseEmailBackend):
    def send_messages(self, email_messages):
        sent = 0
        for message in email_messages or []:
            if not message.recipients():
                continue
            try:
                self._send(message)
            except SMTPException:
                if not self.fail_silently:
                    raise
            else:
                sent += 1
        return sent

    def _send(self, message):
        key = settings.RESEND_API_KEY.strip()
        if not key:
            raise SMTPException('RESEND_API_KEY is not configured.')
        if message.attachments or getattr(message, 'alternatives', None):
            raise SMTPException('This verification email backend does not support attachments or multipart messages.')
        payload = {
            'from': message.from_email, 'to': message.to, 'subject': message.subject,
            'html' if message.content_subtype == 'html' else 'text': message.body,
        }
        for field in ('cc', 'bcc', 'reply_to'):
            value = getattr(message, field)
            if value:
                payload[field] = value
        request = Request('https://api.resend.com/emails',
                          data=json.dumps(payload, ensure_ascii=False).encode('utf-8'),
                          headers={'Authorization': 'Bearer ' + key,
                                   'Content-Type': 'application/json',
                                   'User-Agent': 'Donation-Django/1.0'}, method='POST')
        try:
            with urlopen(request, timeout=settings.EMAIL_TIMEOUT) as response:
                result = json.loads(response.read())
        except HTTPError as error:
            status = error.code
            error.close()
            raise SMTPException(f'Resend rejected the email (HTTP {status}). Check API key, sender domain and quota.') from None
        except (URLError, OSError, ValueError):
            raise SMTPException('Resend email delivery failed. Check provider/network availability.') from None
        if not isinstance(result, dict) or not isinstance(result.get('id'), str) or not result['id']:
            raise SMTPException('Resend did not confirm email acceptance.')
