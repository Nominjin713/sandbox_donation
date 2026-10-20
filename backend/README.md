# Django authentication backend

Зургийн дагуух database хүснэгт, холбоос, PostgreSQL дээр үүсгэх дараалал: [DATABASE.md](DATABASE.md).

Render дээр байрлуулах одоогийн дараалал: [RENDER.md](RENDER.md).

Үйл ажиллагаа үүсгэх backend: `POST /events/create`. Bearer token, request/response жишээ болон validation дүрмийг [events/API.md](events/API.md)-ээс үзнэ үү.

Flutter-ийн нийтлэх, жагсаалт, дэлгэрэнгүй, оролцох/цуцлах урсгал API-тай холбогдсон. Backend-ийн migration-уудыг `manage.py migrate` командаар хэрэгжүүлээд серверээ асаана. Frontend-ийг `flutter run -d chrome --web-port=3000` командаар ажиллуулна; өөр backend хаягт `--dart-define=API_URL=https://YOUR_BACKEND_HOST` ашиглана.

Current online deployment instructions are in [RENDER.md](RENDER.md). Render uses
`DATABASE_URL`; local development uses private `database.local.json` or `DB_*`
variables. People cloning the repo do not receive private database/email settings.
Flutter defaults to the shared Render API. Domain-free Gmail delivery setup:
[GMAIL.md](GMAIL.md).

Requires Python 3.12+ and Django. Registration requires email verification before login.

```powershell
cd backend
python -m venv .venv
.\.venv\Scripts\python.exe -m pip install -r requirements.txt
.\.venv\Scripts\python.exe manage.py migrate
.\.venv\Scripts\python.exe manage.py runserver 127.0.0.1:8080
```

The API runs at http://localhost:8080. Users and tokens persist in the configured PostgreSQL database (SQLite is an explicit test override). Django hashes and validates passwords. Tokens expire after 24 hours; logout revokes them. Only token digests are stored in the database. Authentication endpoints allow 20 requests per IP per minute through Django's local cache (per process).

Endpoints: `POST /auth/register` (name, email, password), `POST /auth/login` (email, password), `POST /auth/verify-email` (email, code), `POST /auth/resend-verification` (email, password), `GET /auth/me`, `POST /auth/logout`. Authenticated requests use `Authorization: Bearer <token>`.

Registration returns `verification_required: true` without a session. Verification accepts a six digit code and returns a session. Login returns 403 with `verification_required: true` until verified. Codes expire after ten minutes and allow five attempts. Resending requires the password, has a 60 second cooldown, and replaces the previous code. Existing accounts must also verify; log in and choose resend to receive a code. Run migrations before starting the updated backend.

Local email settings can be saved in `backend/email.local.json`, which is excluded from Git. Django reads it automatically, including when the server restarts. Environment variables override values in this file. Use this structure with your SMTP account (keep the real password only in the local file):

```json
{
  "EMAIL_BACKEND": "django.core.mail.backends.smtp.EmailBackend",
  "EMAIL_HOST": "smtp.gmail.com",
  "EMAIL_PORT": 587,
  "EMAIL_USE_TLS": true,
  "EMAIL_HOST_USER": "sender@gmail.com",
  "EMAIL_HOST_PASSWORD": "your-app-password",
  "DEFAULT_FROM_EMAIL": "sender@gmail.com"
}
```

Restart the backend after changing this file. Gmail App Password whitespace is removed automatically. Without local settings or environment overrides, development email is printed to the backend terminal. Alternatively, configure environment variables in the same terminal that starts Django (do not commit credentials):

```powershell
$env:EMAIL_BACKEND = 'django.core.mail.backends.smtp.EmailBackend'
$env:EMAIL_HOST = 'smtp.your-provider.com'
$env:EMAIL_PORT = '587'
$env:EMAIL_HOST_USER = 'your-smtp-user'
$env:EMAIL_HOST_PASSWORD = 'your-smtp-password'
$env:EMAIL_USE_TLS = 'true'
$env:DEFAULT_FROM_EMAIL = 'Donation <verified-sender@your-domain.com>'
```

Production defaults to SMTP. Use credentials and an approved sender from your email provider. Email delivery failures return 503; failed registration is rolled back so it can be retried.

In a second terminal, from the repository root:

```powershell
cd frontend/donation_app
flutter pub get
flutter run -d chrome --web-port=3000
```

For Android emulator, use `flutter run --dart-define=API_URL=http://10.0.2.2:8080`. The debug Android manifest permits local HTTP. For a physical device, run the backend with `manage.py runserver 0.0.0.0:8080`, add the computer's LAN address to DJANGO_ALLOWED_HOSTS, and use that address in API_URL.

Environment variables: `DJANGO_DEBUG` (true), `DJANGO_SECRET_KEY`, `DJANGO_ALLOWED_HOSTS` (comma-separated), `CORS_ORIGIN` (http://localhost:3000). Use HTTPS, a production WSGI server, DEBUG=false, a secret key, and your actual frontend origin when deploying. These endpoints use explicit bearer tokens rather than cookies. Frontend sessions are held in memory; restarting the app requires login.

Run backend checks with `.\.venv\Scripts\python.exe manage.py check` and `.\.venv\Scripts\python.exe manage.py test`; frontend checks with `flutter analyze` and `flutter test`.
