"""Gmail API email delivery over HTTPS, using the sender's offline OAuth grant."""
import base64
import hashlib
import json
from smtplib import SMTPException
from threading import Lock
from time import monotonic
from urllib.error import HTTPError, URLError
from urllib.parse import urlencode
from urllib.request import Request, urlopen

from django.conf import settings
from django.core.mail.backends.base import BaseEmailBackend


_token_lock = Lock()
_token_cache = None


def request_json(request, purpose):
    try:
        with urlopen(request, timeout=settings.EMAIL_TIMEOUT) as response:
            result = json.loads(response.read())
    except HTTPError as error:
        status = error.code
        error.close()
        raise SMTPException(f'Gmail API {purpose} failed (HTTP {status}). Check OAuth consent, credentials and quota.') from None
    except (URLError, OSError, ValueError):
        raise SMTPException(f'Gmail API {purpose} failed. Check network/provider availability.') from None
    if not isinstance(result, dict):
        raise SMTPException(f'Gmail API {purpose} returned an invalid response.')
    return result


def access_token():
    global _token_cache
    credentials = {
        'client_id': settings.GMAIL_CLIENT_ID.strip(),
        'client_secret': settings.GMAIL_CLIENT_SECRET.strip(),
        'refresh_token': settings.GMAIL_REFRESH_TOKEN.strip(),
    }
    if not all(credentials.values()):
        raise SMTPException('Configure GMAIL_CLIENT_ID, GMAIL_CLIENT_SECRET and GMAIL_REFRESH_TOKEN.')
    fingerprint = hashlib.sha256(json.dumps(credentials, sort_keys=True).encode()).hexdigest()
    with _token_lock:
        if _token_cache and _token_cache[0] == fingerprint and _token_cache[2] > monotonic():
            return _token_cache[1]
        request = Request('https://oauth2.googleapis.com/token',
                          data=urlencode({**credentials, 'grant_type': 'refresh_token'}).encode(),
                          headers={'Content-Type': 'application/x-www-form-urlencoded'}, method='POST')
        result = request_json(request, 'authorization')
        token = result.get('access_token')
        expiry = result.get('expires_in')
        if not isinstance(token, str) or not token or type(expiry) is not int or expiry <= 0:
            raise SMTPException('Gmail API did not return a valid access token.')
        _token_cache = (fingerprint, token, monotonic() + max(0, expiry - 60))
        return token


class GmailApiEmailBackend(BaseEmailBackend):
    def send_messages(self, email_messages):
        global _token_cache
        sent = 0
        for message in email_messages or []:
            if not message.recipients():
                continue
            try:
                # Verification messages are plain text; reject hidden recipients to
                # avoid a MIME Bcc header accidentally exposing their addresses.
                if message.bcc:
                    raise SMTPException('Gmail verification backend does not support Bcc.')
                raw = base64.urlsafe_b64encode(message.message().as_bytes()).decode('ascii')
                request = Request('https://gmail.googleapis.com/gmail/v1/users/me/messages/send',
                                  data=json.dumps({'raw': raw}).encode(),
                                  headers={'Content-Type': 'application/json',
                                           'Authorization': 'Bearer ' + access_token()}, method='POST')
                result = request_json(request, 'delivery')
                if not isinstance(result.get('id'), str) or not result['id']:
                    raise SMTPException('Gmail API did not confirm email acceptance.')
            except SMTPException:
                with _token_lock:
                    _token_cache = None
                if not self.fail_silently:
                    raise
            else:
                sent += 1
        return sent
