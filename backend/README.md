# Django authentication backend

Requires Python 3.12+ and Django. This project contains only registration and login functionality.

```powershell
cd backend
python -m venv .venv
.\.venv\Scripts\python.exe -m pip install -r requirements.txt
.\.venv\Scripts\python.exe manage.py migrate
.\.venv\Scripts\python.exe manage.py runserver 127.0.0.1:8080
```

The API runs at http://localhost:8080. Users and tokens persist in `db.sqlite3`. Django hashes and validates passwords. Tokens expire after 24 hours; logout revokes them. Only token digests are stored in the database. Authentication endpoints allow 20 requests per IP per minute through Django's local cache (per process).

Endpoints: `POST /auth/register` (name, email, password), `POST /auth/login` (email, password), `GET /auth/me`, `POST /auth/logout`. Authenticated requests use `Authorization: Bearer <token>`.

In a second terminal, from the repository root:

```powershell
cd frontend/donation_app
flutter pub get
flutter run -d chrome --web-port=3000
```

For Android emulator, use `flutter run --dart-define=API_URL=http://10.0.2.2:8080`. The debug Android manifest permits local HTTP. For a physical device, run the backend with `manage.py runserver 0.0.0.0:8080`, add the computer's LAN address to DJANGO_ALLOWED_HOSTS, and use that address in API_URL.

Environment variables: `DJANGO_DEBUG` (true), `DJANGO_SECRET_KEY`, `DJANGO_ALLOWED_HOSTS` (comma-separated), `CORS_ORIGIN` (http://localhost:3000). Use HTTPS, a production WSGI server, DEBUG=false, a secret key, and your actual frontend origin when deploying. These endpoints use explicit bearer tokens rather than cookies. Frontend sessions are held in memory; restarting the app requires login.

Run backend checks with `.\.venv\Scripts\python.exe manage.py check` and `.\.venv\Scripts\python.exe manage.py test`; frontend checks with `flutter analyze` and `flutter test`.
