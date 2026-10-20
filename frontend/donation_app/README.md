# Donation app

Flutter-ээр бүртгүүлэх, email код баталгаажуулах, нэвтрэх, event үүсгэх/жагсаах,
оролцох/цуцлах апп. Үндсэн API нь online Render backend байна.

```powershell
flutter pub get
flutter run -d chrome --web-port=3000
```

Локал Django/PostgreSQL асаах шаардлагагүй. Backend URL-ийг өөрчлөх бол
`--dart-define=API_URL=https://YOUR_BACKEND_HOST` ашиглана. Локал web backend-д
`http://localhost:8080`, Android emulator-д `http://10.0.2.2:8080` гэж ил тод заана.

Бусад хэрэглэгчийн email баталгаажуулалтыг нээхэд домайнгүй [Gmail API](../../backend/GMAIL.md)
OAuth эсвэл Resend verified domain-оо backend-д тохируулна. `onboarding@resend.dev`
нь зөвхөн account эзэмшигчийн inbox руу туршилтын код явуулна.
Код баталгаажуулсны дараа нэвтэрнэ; session нь санах ойд
хадгалагдах тул browser refresh/апп дахин асаахад дахин нэвтэрнэ.

Багийн заавар: [README](../../README.md). Шалгалт: `flutter analyze`, `flutter test`.
