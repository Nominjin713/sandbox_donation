# Deploy Django with Supabase and Gmail

The database is already online. The Django API must also be hosted for other people to use it without running their own backend. This repository includes a Dockerfile and a Waitress production server. Local database/email settings are intentionally excluded from both Git and Docker images.

## Before deploying

Database settings and data exports were previously committed to Git. They are now removed from tracking, but remain in Git history. Reset the Supabase database password in the project's Connect panel and update the private `database.local.json` and `database.supabase.local.json` files. Do not force-push rewritten history without coordinating with collaborators.

From `backend`, regenerate the private hosting environment file after updating the password:

```powershell
.\.venv\Scripts\python.exe export_deploy_env.py
```

`deploy.env` contains real credentials. Import it into hosting environment variables, keeping the values private. It includes a generated Django secret key that remains stable on subsequent exports. Never commit this file. When entering variables manually, use their values without the surrounding JSON quotation marks. `DB_SCHEMA=donation` is required to access the existing Supabase tables.

## Hosting with Koyeb

Koyeb supports outbound SMTP on port 587, which is needed for the existing Gmail account. Render free services and Railway Free/Trial/Hobby do not support the required SMTP connection. Koyeb account verification requires a card, and signup may select a paid plan; check billing before confirming. A `free` web service instance is available for testing.

1. Connect your GitHub repository in Koyeb. The deployment files must first be committed and pushed after reviewing the secret-file removals.
2. Create a **Web Service**, set the working directory to `backend`, and use the **Dockerfile** builder with `Dockerfile` in that directory.
3. Choose an instance explicitly, checking its cost before confirming. A paid service has not been provisioned by this repository.
4. Configure the environment variables from the private `deploy.env`. Koyeb supplies `KOYEB_PUBLIC_DOMAIN`, which Django automatically allows. For another provider, explicitly set `DJANGO_ALLOWED_HOSTS` to your backend hostname without `https://`.
5. Expose HTTP port **8080**, route `/` to it, and set the HTTP health check path to **`/health`**.
6. Deploy. Startup applies database migrations and runs Waitress. Verify `https://YOUR_BACKEND_HOST/health` returns `{"status":"ok"}` and test registration/email delivery before sharing the app.

The Docker image has not been built locally unless Docker is available. Keep one service instance when relying on the current in-memory per-IP authentication rate limiter. Configure a shared cache before scaling horizontally.

## Flutter after deployment

From `frontend/donation_app`, use the actual backend HTTPS URL:

```powershell
flutter run -d chrome --web-port=3000 --dart-define=API_URL=https://YOUR_BACKEND_HOST
```

For an Android release:

```powershell
flutter build apk --dart-define=API_URL=https://YOUR_BACKEND_HOST
```

The URL is public; no database or Gmail credentials belong in Flutter. For a hosted Flutter website, add its exact origin to the backend's comma-separated `CORS_ALLOWED_ORIGINS` variable. The initial hosting environment allows local frontend origins on port 3000 for people cloning the repo.

Provider references:
- https://www.koyeb.com/docs/deploy/django
- https://www.koyeb.com/docs/faqs/general
- https://www.koyeb.com/docs/faqs/pricing
- https://render.com/docs/free
- https://docs.railway.com/networking/outbound-networking
