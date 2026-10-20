# Render дээр байрлуулах

Локал PostgreSQL-ийн хүснэгтүүд бэлэн болсны дараа энэ дарааллаар байрлуулна.
Локал `127.0.0.1` database-д Render сервер холбогдохгүй. Render дээр тусдаа
PostgreSQL үүсгэнэ; `start_server.py` нь ижил migration-уудаар хүснэгтүүдийг байгуулна.
Локал хэрэглэгчид/event өгөгдөл автоматаар хуулагдахгүй. Өгөгдөл шилжүүлэх бол
deployment-ээс тусдаа backup/restore алхмыг төлөвлөнө.

## 1. PostgreSQL

Render Dashboard → **New → Postgres**:

- Name: `donation-db`
- Database: `donation`
- Region: backend-тэй ижил
- Plan: сонгосон багцын үнэ, хадгалах хугацааг шалгаад үүсгэнэ.

Үүссэний дараа **Connections → Internal Database URL**-ийг backend-ийн environment-д
оруулна. URL нь password агуулдаг тул чат, Git, Flutter кодод бичихгүй.

## 2. Django backend

Эхлээд өөрчлөлтүүдийг GitHub repository руу push хийсэн байна. Database/email хувийн
тохиргоо болон `backups/` нь Git-д орохгүй.

Render → **New → Web Service → GitHub repository**:

- Repository: `Nominjin713/sandbox_donation`
- Root Directory: `backend`
- Runtime/Language: **Docker**
- Dockerfile: `Dockerfile` (root directory-той харьцангуй)
- Region: database-тай ижил
- Health Check Path: `/health`
- Instance type: сонгосон имэйл хувилбарт тохирох багц.

Dockerfile-ийн команд `python start_server.py`; migration болон Waitress server
автоматаар ажиллана. Docker deployment-д `runserver` ашиглахгүй. Render-ийн
`PORT` хувьсагчийг сервер автоматаар уншина.

## 3. Environment

| Key | Value |
|---|---|
| `DATABASE_URL` | Render PostgreSQL-ийн **Internal Database URL** |
| `DJANGO_DEBUG` | `false` |
| `DJANGO_SECRET_KEY` | Локал түлхүүрээс тусдаа, нэг удаа үүсгэсэн санамсаргүй урт түлхүүр |
| `CORS_ALLOWED_ORIGINS` | `http://localhost:3000,http://127.0.0.1:3000` болон hosted frontend-ийн бодит origin |
| `RUN_MIGRATIONS` | `true` |

Secret key үүсгэх локал команд:

```powershell
.\.venv\Scripts\python.exe -c "import secrets; print(secrets.token_urlsafe(64))"
```

Түлхүүрийг Render Environment-д хадгална. `RENDER_EXTERNAL_HOSTNAME`-ийг Django
автоматаар allowed hosts-д нэмнэ; custom domain байвал `DJANGO_ALLOWED_HOSTS`-д
Render болон custom hostname-уудаа таслалаар бичнэ (https:// оруулахгүй).

Render дээр `DATABASE_ENGINE=sqlite`, локал `DB_*`, хуучин Supabase-ийн холболт
эсвэл локал `deploy.env`-ийг хуулж оруулахгүй. `DATABASE_URL` нь database settings-д
давуу үйлчилдэг. Render URL ашиглахад хуучин локал schema тохиргоог өвлөхгүй.

## 4. Имэйл

**Free Web Service дээр одоогийн Gmail SMTP ажиллахгүй:** Render нь SMTP-ийн
25/465/587 портуудыг хаадаг. Үнэгүй service сонговол HTTPS имэйл API-ийн backend
болон provider-ийн түлхүүр/баталгаажсан sender-ийг тусад нь тохируулах шаардлагатай.
Энэ repository-д `accounts.email_backend.ResendEmailBackend` HTTPS backend нэмэгдсэн.

Resend тохируулах:

1. https://resend.com дээр account үүсгэнэ.
2. **API Keys → Create API Key** → Sending access сонгоод key-г Render Environment-д хадгална.
3. Эхний туршилтад `onboarding@resend.dev` илгээгч ашиглаж болно, гэхдээ зөвхөн
   Resend account-аа бүртгүүлсэн өөрийн имэйл рүү илгээнэ.
4. Бүх хэрэглэгчид код илгээхийн тулд **Domains → Add Domain**-д өөрийн domain-оо
   нэмээд provider-ийн заасан DNS бичлэгүүдийг domain дээрээ тохируулж Verified болгоно.
   Gmail эсвэл `onrender.com` хаягийг өөрийн domain болгон баталгаажуулах боломжгүй.
5. Render → backend service → **Environment**:

| Key | Value |
|---|---|
| `EMAIL_BACKEND` | `accounts.email_backend.ResendEmailBackend` |
| `RESEND_API_KEY` | Resend-ээс авсан хувийн API key |
| `DEFAULT_FROM_EMAIL` | Туршилтад `onboarding@resend.dev`; бодит хэрэглээнд баталгаажсан domain-ийн sender |

**Save, rebuild, and deploy** хийнэ. Шинэ backend код GitHub-д push хийгдсэн байх ёстой.
Gmail App Password нь Resend API key-г орлохгүй. Resend dashboard-ийн Emails/Logs-оор
provider хүлээн авсан, хүргэсэн эсэхийг шалгана. API амжилт нь inbox-д хүрсэн гэсэн баталгаа биш.
Туршилтын sender ашиглахдаа зөвхөн өөрийн Resend account email-ээр app-д бүртгүүлнэ.

SMTP зөвшөөрдөг төлбөртэй Web Service дээр одоогийн Gmail тохиргоо:

| Key | Value |
|---|---|
| `EMAIL_BACKEND` | `django.core.mail.backends.smtp.EmailBackend` |
| `EMAIL_HOST` | `smtp.gmail.com` |
| `EMAIL_PORT` | `587` |
| `EMAIL_USE_TLS` | `true` |
| `EMAIL_HOST_USER` | Илгээгч Gmail |
| `EMAIL_HOST_PASSWORD` | Gmail App Password |
| `DEFAULT_FROM_EMAIL` | Илгээгч Gmail |

Free PostgreSQL нь хугацаа/нөөцлөлтийн хязгаартай тул байнгын өгөгдөлд багцыг
сонгохын өмнө Render-ийн одоогийн нөхцөлийг шалгана.

## 5. Deploy дараах шалгалт

1. Logs дээр migration-ууд `OK`, server ажилласан байх.
2. `https://YOUR-SERVICE.onrender.com/health` → `{"status":"ok"}`.
3. `https://YOUR-SERVICE.onrender.com/events/` → JSON жагсаалт.
4. Шинэ бүртгэл → бодит имэйл → баталгаажуулах код → login → event үүсгэх → оролцох/цуцлах.

Flutter:

```powershell
cd frontend/donation_app
flutter run -d chrome --web-port=3000 --dart-define=API_URL=https://YOUR-SERVICE.onrender.com
```

Render account-д service үүсгэж, URL-ээр нь шалгахаас өмнө online deployment
дууссан гэж тооцохгүй.

Эх сурвалж:

- [Django deployment](https://render.com/docs/deploy-django)
- [Docker deployment](https://render.com/docs/docker)
- [Free service limits, SMTP, PostgreSQL expiration](https://render.com/docs/free)
- [Resend domain verification](https://resend.com/docs/dashboard/domains/introduction)
- [Resend test sender restrictions](https://resend.com/docs/knowledge-base/403-error-resend-dev-domain)
