"""One-time sender OAuth consent. Exports private Render variables without sending mail."""
import argparse
from datetime import datetime
from email.utils import parseaddr
import json
from pathlib import Path
import sys


BASE = Path(__file__).resolve().parent
SCOPE = 'https://www.googleapis.com/auth/gmail.send'


def export_credentials(credentials, sender):
    if not credentials.refresh_token:
        raise ValueError('No refresh token received. Reauthorize with offline access and consent.')
    values = {
        'EMAIL_BACKEND': 'accounts.gmail_backend.GmailApiEmailBackend',
        'GMAIL_CLIENT_ID': credentials.client_id,
        'GMAIL_CLIENT_SECRET': credentials.client_secret,
        'GMAIL_REFRESH_TOKEN': credentials.refresh_token,
        'DEFAULT_FROM_EMAIL': sender,
    }
    if any(not isinstance(value, str) or not value or '\n' in value or '\r' in value
           for value in values.values()):
        raise ValueError('OAuth credentials/sender are incomplete or invalid.')
    destination = BASE / 'gmail.render.env'
    if destination.exists():
        directory = BASE / 'backups'
        directory.mkdir(exist_ok=True)
        backup = directory / ('gmail-before-setup-' + datetime.now().strftime('%Y%m%d-%H%M%S-%f') + '.env')
        with backup.open('xb') as file:
            file.write(destination.read_bytes())
    temporary = destination.with_suffix('.env.tmp')
    temporary.write_text(''.join(f'{key}={value}\n' for key, value in values.items()), encoding='utf-8')
    temporary.replace(destination)
    return destination


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--credentials', type=Path, default=BASE / 'gmail-client.local.json',
                        help='Desktop OAuth client JSON downloaded from Google Cloud')
    parser.add_argument('--sender', help='The Gmail address you will authorize in the browser')
    args = parser.parse_args()
    if not args.credentials.is_file():
        print('Desktop OAuth client JSON not found. Follow GMAIL.md first.')
        print('Save it as backend/gmail-client.local.json, or pass --credentials "PATH".')
        return 1
    with args.credentials.open(encoding='utf-8-sig') as file:
        client = json.load(file)
    if not isinstance(client, dict) or not isinstance(client.get('installed'), dict):
        print('Use a Google OAuth Desktop app client JSON, not an API key or service account.')
        return 1
    try:
        from google_auth_oauthlib.flow import InstalledAppFlow
    except ImportError:
        print('Install the local helper first: python -m pip install -r requirements-gmail-setup.txt')
        return 1
    sender = (args.sender or input('Sender Gmail address (choose the same account in the browser): ')).strip()
    if '\n' in sender or '\r' in sender or parseaddr(sender)[1] != sender or '@' not in sender:
        print('Enter a plain email address.')
        return 1
    flow = InstalledAppFlow.from_client_config(client, scopes=[SCOPE])
    print('Authorize only the Gmail account that will SEND verification codes. No email is sent by this helper.')
    credentials = flow.run_local_server(
        host='127.0.0.1', port=0, timeout_seconds=180,
        authorization_prompt_message='Opening your browser for Google OAuth consent...',
        success_message='Gmail sender authorization completed. You can close this tab.',
        access_type='offline', prompt='consent',
    )
    destination = export_credentials(credentials, sender)
    print('GMAIL_API_SETUP_READY:', destination.name)
    print('Render backend > Environment > Edit > Add from .env: paste this private file content.')
    print('Save, rebuild and deploy the new backend code. Do not share the file or commit it.')
    return 0


if __name__ == '__main__':
    try:
        raise SystemExit(main())
    except Exception as error:
        # OAuth/network exceptions can include token response data; never print it.
        print(f'Gmail setup failed ({type(error).__name__}). Check Google Cloud OAuth settings and try again.')
        sys.exit(1)
