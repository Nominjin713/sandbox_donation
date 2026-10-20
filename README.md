# Sandbox Donation

Flutter апп + Django API + PostgreSQL. Багийнхан нэг Render backend, нэг online
PostgreSQL database ашиглана. Database-ийн нууц үг болон email API key нь зөвхөн backend-д байна.

## Багийн гишүүн ажиллуулах

Flutter болон Chrome суулгасан байна. Repository-г clone/pull хийсний дараа:

```powershell
cd frontend/donation_app
flutter pub get
flutter run -d chrome --web-port=3000
```

Апп үндсэн тохиргоогоор `https://donation-backend-bkms.onrender.com` руу холбогдоно.
Локал Django, PostgreSQL болон хувийн database/email JSON файл шаардлагагүй.
Chrome-ийн port 3000 нь backend-ийн CORS тохиргоонд зөвшөөрөгдсөн байх ёстой.
Render Free унтсан байвал эхний хүсэлт нэг минут орчим хүлээж болно.

Хүн бүр өөрийн бүртгэлээр нэвтэрнэ. Бүртгэл, event, оролцоо online PostgreSQL-д
хадгалагдана; event жагсаалтыг бусад хэрэглэгч уншина.

**Бусдын шинэ бүртгэлийг нээхэд дутуу:** домайнгүй бол [Gmail API](backend/GMAIL.md)
заавраар илгээгчийн OAuth зөвшөөрөл авч Render Environment-ээ тохируулна.
Resend сонговол өөрийн verified domain шаардлагатай; `onboarding@resend.dev`
нь зөвхөн account эзэмшигчийн имэйл рүү туршилтын код илгээнэ.
Нэвтэрсэн session нь санах ойд хадгалагдана;
аппыг дахин асаах/refresh хийхэд дахин нэвтэрнэ.

## Локал backend хөгжүүлэх

Локал backend рүү тусгайлан холбохдоо:

```powershell
flutter run -d chrome --web-port=3000 --dart-define=API_URL=http://localhost:8080
```

Android emulator-д `--dart-define=API_URL=http://10.0.2.2:8080` ашиглана.
Database болон backend setup: [DATABASE.md](backend/DATABASE.md), [backend README](backend/README.md).
Render/email deployment: [RENDER.md](backend/RENDER.md).

Render Free PostgreSQL 30 хоногийн хугацаатай тул байнгын ашиглалтад database
багц болон backup-аа тохируулна: [Render free limits](https://render.com/docs/free).
