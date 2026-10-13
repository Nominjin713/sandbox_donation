# donation_app

Монгол хэлтэй бүртгүүлэх, нэвтрэх Flutter дэлгэцүүд. Django API-тай холбогдоно.

Backend-ийг төслийн үндсэн хавтсаас ажиллуулах:

```powershell
cd backend
.\.venv\Scripts\python.exe manage.py migrate
.\.venv\Scripts\python.exe manage.py runserver 127.0.0.1:8080
```

Frontend-ийг өөр терминалаас ажиллуулах:

```powershell
cd frontend/donation_app
flutter pub get
flutter run -d chrome --web-port=3000
```

Android emulator нь `http://10.0.2.2:8080`, web болон desktop нь `http://localhost:8080` хаягийг ашиглана. Өөр backend хаяг ашиглах бол `--dart-define=API_URL=https://your-api.example.com` тохируулна. Утаснаас холбох бол компьютерийн LAN хаягийг ашиглаж, backend-ийн allowed hosts тохиргоонд нэмнэ.

Нэвтэрсэн session нь санах ойд хадгалагдах тул аппыг дахин эхлүүлэхэд нэвтэрнэ. Бүртгүүлсний дараа шууд нэвтэрнэ.

Шалгах командууд: `flutter analyze`, `flutter test`.

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Learn Flutter](https://docs.flutter.dev/get-started/learn-flutter)
- [Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Flutter learning resources](https://docs.flutter.dev/reference/learning-resources)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.
