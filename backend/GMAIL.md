# Gmail API: домайнгүй, Render Free дээр имэйл илгээх

Бүртгэлийн кодыг илгээгчийн Gmail account-аас HTTPS API-аар илгээнэ. Gmail-ийн
App Password энэ арга дээр ашиглахгүй. **Зөвхөн илгээгч** Google OAuth зөвшөөрөл
өгнө; аппын хэрэглэгч бүр өөрийн Gmail-д эрх өгөх шаардлагагүй.

## 1. Google Cloud project

1. https://console.cloud.google.com/ нээгээд илгээгч Gmail-аараа нэвтэр.
2. Project selector → **New Project** → `donation-mail` → **Create**.
3. Тэр project-оо сонгоод **APIs & Services → Library → Gmail API → Enable**.

## 2. OAuth зөвшөөрөл

**Google Auth Platform → Get Started**:

- App name: `Donation Mail`
- User support email: таны илгээгч Gmail
- Audience: **External** (энгийн Gmail хэрэглэгчид)
- Contact email: таны Gmail
- Google-ийн нөхцөлийг уншиж зөвшөөрөөд Create.

**Data Access → Add or remove scopes** дотор зөвхөн
`https://www.googleapis.com/auth/gmail.send` нэмнэ. Gmail унших/full access scope хэрэггүй.

**Audience → Test users → Add users** дээр зөвхөн илгээгч Gmail-аа нэмнэ.

Testing төлөвтэй External app-ийн refresh token **7 хоногийн дараа дуусна**.
Удаан ажиллуулахын өмнө Audience → **Publish app / In production** тохиргоог
шийдэж, шинэ refresh token авна. Production төлөв нь Google verification-тэй ижил
утгатай биш. Өөрийн Gmail-ийг цөөн танил багийн хэрэглээнд зөвшөөрөхөд personal-use
exception байж болно; Google-ийн unverified-app warning болон user cap үйлчилнэ.
Google танай app-д verification шаардвал түүнийг дагана. Нийтийн production
app-д энэ туршилтын тохиргоог хангалттай гэж үзэхгүй.

## 3. Desktop OAuth client

Google Auth Platform → **Clients → Create client**:

- Application type: **Desktop app**
- Name: `Donation sender setup`
- Create → **Download JSON**.

Файлыг `backend/gmail-client.local.json` гэж хадгална. Энэ нь Git/Docker-д орохгүй.
API key эсвэл Service Account JSON сонгохгүй. Client secret JSON-ийг чатад илгээхгүй.

## 4. Компьютер дээр илгээгчийг зөвшөөрүүлэх

```powershell
cd backend
.\.venv\Scripts\python.exe -m pip install -r requirements-gmail-setup.txt
.\.venv\Scripts\python.exe setup_gmail_api.py
```

Илгээгч Gmail-аа оруулаад нээгдсэн browser дээр **яг тэр account**-аа сонгон,
өөрийн үүсгэсэн `Donation Mail` app-ийн gmail.send зөвшөөрлийг шалгаж олгоно.
Callback нь зөвхөн энэ нэг удаагийн зөвшөөрөлд localhost дээр ажиллана; Render
backend болон database-ийн online хаяг өөрчлөгдөхгүй. Helper өөрөө имэйл илгээхгүй.

Амжилттай бол `GMAIL_API_SETUP_READY: gmail.render.env` гарна. Энэ хувийн файлд
refresh token болон Render-ийн 5 тохиргоо байна. Gmail/SMTP локал тохиргоог
автоматаар солихгүй. OAuth зөвшөөрлийг цуцлах, Google password/account policy
өөрчлөгдөх зэрэгт refresh token дахин авах шаардлага үүсэж болно.

## 5. Render Environment

Шинэ backend кодоо GitHub руу push хийсэн байна. Render → **donation-backend →
Environment → Edit → Add from .env** хэсэгт `gmail.render.env`-ийн агуулгыг
хуулж импортлоно (эсвэл дараах 5 утгыг тус тусад нь нэмнэ):

| Key | Value |
|---|---|
| EMAIL_BACKEND | accounts.gmail_backend.GmailApiEmailBackend |
| GMAIL_CLIENT_ID | Helper-ийн гаргасан client ID |
| GMAIL_CLIENT_SECRET | Helper-ийн гаргасан client secret |
| GMAIL_REFRESH_TOKEN | Helper-ийн гаргасан refresh token |
| DEFAULT_FROM_EMAIL | OAuth зөвшөөрөл өгсөн Gmail хаяг |

Өмнөх EMAIL_BACKEND болон DEFAULT_FROM_EMAIL мөрүүдийг солих; давхар нэртэй
утга үүсгэхгүй. DATABASE_URL, DJANGO_SECRET_KEY, CORS тохиргоогоо хэвээр хадгална.
**Save, rebuild, and deploy** дарна. Google token, secret-ийг Git/Flutter/чатад тавихгүй.

## 6. Бодит ажиллагааг шалгах

Өөрийн эсвэл тест хийхийг зөвшөөрсөн багийн хүний имэйлээр бүртгүүлж:
код хүлээн авах → баталгаажуулах → нэвтрэх → event үүсгэх → дахин ачаалах →
оролцох/цуцлах урсгалыг шалгана. Provider API амжилттай хүлээн авсан нь inbox-д
заавал хүрсэн гэсэн баталгаа биш; Spam болон Gmail-ийн Sent хэсгийг шалгана.
Gmail-ийн өдөр тутмын илгээлтийн хязгаар болон Google API quota үйлчилнэ.

Эх сурвалж:

- [Google OAuth desktop setup](https://developers.google.com/workspace/gmail/api/quickstart/python)
- [Gmail API sending](https://developers.google.com/workspace/gmail/api/guides/sending)
- [OAuth token expiration](https://developers.google.com/identity/protocols/oauth2)
- [Personal use and verification](https://developers.google.com/identity/protocols/oauth2/production-readiness/sensitive-scope-verification)
