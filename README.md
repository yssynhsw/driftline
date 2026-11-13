# Driftline

Travel accounts stored in local SQLite. Flutter is the client. The database enforces roles, verification codes, lockout, and the single administrator.

## Run

```bash
flutter run -d web-server --web-port 8080
```

Open http://localhost:8080.

Windows desktop needs the Visual Studio “Desktop development with C++” workload. Android needs an Android SDK.

## Test administrator

Public registration always creates a `user`. The app never accepts a role from the form.

This development account is created on first launch when no administrator exists yet:

| | |
| --- | --- |
| Email | `admin@driftline.app` |
| Password | `Driftline#2026` |
| Name | Driftline Admin |
| Country | Morocco |
| Language | English |
| Travel preference | City |
| Role | admin (email already verified) |

```bash
flutter run -d web-server --web-port 8080 --dart-define=ADMIN_EMAIL=admin@driftline.app --dart-define=ADMIN_PASSWORD=Driftline#2026
```

On PowerShell, quote each flag so `#` is not treated as a comment:

```powershell
flutter run -d web-server --web-port 8080 "--dart-define=ADMIN_EMAIL=admin@driftline.app" "--dart-define=ADMIN_PASSWORD=Driftline#2026"
```

Reload http://localhost:8080, then sign in with that email and password. The middle tab opens the admin dashboard. The account is stored in that browser's local SQLite, so each browser creates it once on first load of this build.

A later launch with the same flags does nothing if an admin already exists, or if that email is already registered. The password is passed at run time and is not hardcoded in Dart.

## What is real in this build

- Registration, login, logout, remembered session, and password visibility.
- Email and reset codes are sent with Resend. They are hashed, expire in 10 minutes, allow 5 attempts, and can be sent again after 60 seconds. The code is only in the email.
- Phone verification uses the same expiry and attempt rules. Twilio sends the code. The code is only in the text.
- Five failed logins lock the account for 15 minutes. Registration is limited to 5 attempts per 10 minutes in the running process.
- Profile edit, password change (current password required), and account deletion (current password required). The administrator account cannot be deleted or suspended from the app.
- Admin dashboard: counts, search, sort, pages of 6, suspend, restore, delete, trip management, and an audit log. An admin reset code is emailed. The dialog shows the code only when Resend rejects it.

## Not configured

Google sign-in, SMS, and CAPTCHA stay closed until their own keys exist. They do not create accounts and they do not pretend to succeed. Email is sent when the local relay is running. The app does not use Firebase.

| Service | Status | What you need |
| --- | --- | --- |
| Google | Pending | A Google OAuth client ID. Driftline does not use Firebase. |
| Email delivery | Resend | Start the local relay before signup or password reset. The API key stays in that process and is not stored in the app or the repo. |
| SMS OTP | Twilio | The relay uses `TWILIO_ACCOUNT_SID` and `TWILIO_AUTH_TOKEN`. A trial account must verify a phone number and claim a sending number before texts can leave. Set that number as `TWILIO_FROM`. Profile numbers need a country code, such as `+212612345678`. Trial accounts can text only numbers verified in the Twilio console. |
| CAPTCHA | Google reCAPTCHA v3 | Sign-in and sign-up request a token in the background. The site key is public. `RECAPTCHA_SECRET` stays in `tool/local.env`. |
| Profile photo | Gallery, camera, and crop | The cropped JPEG is stored in SQLite. Camera and photo-library permission prompts appear on iOS and Android. |

## Email

The Flutter app calls `http://127.0.0.1:8787`. That process holds the Resend key and sends the message.

```powershell
$env:RESEND_API_KEY = "re_your_key"
$env:TWILIO_ACCOUNT_SID = "ACyour_sid"
$env:TWILIO_AUTH_TOKEN = "your_auth_token"
$env:TWILIO_FROM = "+15551234567"
$env:RECAPTCHA_SECRET = "your_recaptcha_secret"
dart run tool/mail_server.dart
```

Leave that window open on its own. It is a separate process from `flutter run`. You can also put the same values in `tool/local.env`, which stays off git. The relay reads that file when the variables are not already set. The default sender is `Driftline <onboarding@resend.dev>` until `RESEND_FROM` is a verified domain. Signup shows Resend's error when a message is rejected. It does not show a code on screen.

`TWILIO_FROM` is the sending number. This trial still needs a verified phone in the Twilio console before that number can be claimed. Profile phones need a country code, such as `+212612345678`.

Session id is stored in shared preferences on this development build. Production should move that token to platform secure storage and keep authorization on a server, not in the Flutter binary.

## Gestion 2 — Voyages et itinéraires

The same `driftline.db` now holds itinerary days and steps. Regular accounts open **Voyages** instead of a traveler directory. The assistant tab, weather chip, campfire palette, and Fraunces type stay on every screen.

Gemini itineraries can use the local relay `GEMINI_API_KEY` in `tool/local.env`, or the Spring proxy in `backend/` for classmates. Never put that key in Dart. See `docs/gestion2-soutenance.md` and `backend/README.md`.
