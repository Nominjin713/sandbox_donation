"""Django email backend that sends through the Resend HTTP API (no SMTP, no extra deps)."""
import json
import logging
import urllib.error
import urllib.request

from django.conf import settings
from django.core.mail.backends.base import BaseEmailBackend

logger = logging.getLogger(__name__)

RESEND_URL = 'https://api.resend.com/emails'


class ResendEmailBackend(BaseEmailBackend):
    def send_messages(self, email_messages):
        api_key = getattr(settings, 'RESEND_API_KEY', '')
        if not api_key:
            logger.error('RESEND_API_KEY is not set')
            if self.fail_silently:
                return 0
            raise RuntimeError('RESEND_API_KEY is not set')

        sent = 0
        for message in email_messages:
            payload = {
                'from': message.from_email or settings.DEFAULT_FROM_EMAIL,
                'to': list(message.to),
                'subject': message.subject,
                'text': message.body,
            }
            request = urllib.request.Request(
                RESEND_URL,
                data=json.dumps(payload).encode('utf-8'),
                headers={
                    'Authorization': f'Bearer {api_key}',
                    'Content-Type': 'application/json',
                    # Resend (Cloudflare) rejects the default Python-urllib User-Agent
                    'User-Agent': 'donation-backend/1.0',
                },
                method='POST',
            )
            try:
                with urllib.request.urlopen(request, timeout=10) as response:
                    if 200 <= response.status < 300:
                        sent += 1
            except urllib.error.HTTPError as exc:
                body = exc.read().decode('utf-8', 'replace')
                logger.error('Resend API failed: HTTP %s body=%s', exc.code, body)
                if not self.fail_silently:
                    raise
            except Exception:
                logger.exception('Resend API request failed')
                if not self.fail_silently:
                    raise
        return sent