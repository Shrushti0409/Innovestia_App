# Innovestia

Innovestia is a Flutter application and Node.js/MongoDB API for connecting startups with investors.

## Run the Flutter app

Start the backend on port `8081` first, then run Flutter with the platform's
local URL (the defaults are shown below):

```powershell
flutter pub get
flutter run
```

The app defaults to `http://10.0.2.2:8081/api` on Android Emulator and
`http://localhost:8081/api` on Windows and Web. `API_BASE_URL` can be supplied
with or without the final `/api`; the client normalizes it to one `/api` path.
Use these development URLs as appropriate:

```powershell
# Android Emulator
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8081/api
# Windows or Web
flutter run --dart-define=API_BASE_URL=http://localhost:8081/api
# Physical Android phone on the same Wi-Fi (replace with this PC's LAN IPv4)
flutter run --dart-define=API_BASE_URL=http://192.168.1.10:8081/api
```

If port 8081 is already occupied, identify and stop the service that owns it
before starting Innovestia. The Flutter client must reach Innovestia on the
same port. Android cleartext HTTP is enabled only in debug builds; use HTTPS
for release builds and pass its URL with `--dart-define=API_BASE_URL=...`.

## Run the backend

```powershell
cd backend
npm install
npm run dev
```

`backend/.env` must select the app-only database
`mongodb://127.0.0.1:27017/innovestia_app` and contain a secure `JWT_SECRET`.
The backend validates the selected database at startup and loads this `.env`
relative to `backend/server.js`. Start it from the project root with
`npm --prefix backend run dev`, or change into `backend` and run `npm run dev`.
Confirm the API is listening with `http://localhost:8081/health`.

Configure `RESEND_API_KEY` and `EMAIL_FROM` in `backend/.env` for verification mail. OTPs and credentials are not logged. Pitch-deck upload is not enabled until remote storage is configured. Never add provider credentials to Flutter source or Git.

## Quality checks

```powershell
dart format lib test
flutter analyze
flutter test
```

## Android release

For a release APK, use an HTTPS API URL reachable by the phone. If using
ngrok, start `ngrok http 8081`, then use the current URL shown by ngrok (the
URL can change between tunnel sessions):

```powershell
flutter build apk --release --dart-define=API_BASE_URL=https://your-current-host.ngrok-free.dev/api
```

Release signing, a unique verified Android application ID, a production icon, remote storage credentials, push-notification credentials, and backend deployment require the account/keys owned by the product team. They are deliberately not fabricated or stored in this repository.
