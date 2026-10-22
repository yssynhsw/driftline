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
- Email and reset codes are hashed, expire in 10 minutes, allow 5 attempts, and resend after 60 seconds. The screen shows the code because no mail provider is configured. That is a local database code, not a delivered email.
- Phone verification uses the same local code rules. No SMS is sent.
- Five failed logins lock the account for 15 minutes. Registration is limited to 5 attempts per 10 minutes in the running process.
- Profile edit, password change (current password required), and account deletion (current password required). The administrator account cannot be deleted or suspended from the app.
- Admin dashboard: counts, search, sort, pages of 6, suspend, restore, delete, trip management, and an audit log. Reset codes issued by an admin are shown once and written to the audit log.

## Not configured

These buttons and checks fail closed. They do not create accounts and they do not pretend to succeed.

| Service | Status | What you need |
| --- | --- | --- |
| Google, Apple, Facebook, Microsoft | Pending | Official OAuth / OpenID client IDs for each provider. Apple also needs an Apple Developer account and the Sign in with Apple capability. |
| Email delivery | Pending | SMTP or a provider such as Resend, plus a server that sends the code. The app must stop returning the plaintext code once mail works. |
| SMS OTP | Pending | An SMS provider and a server that sends the code. |
| CAPTCHA | Not added | A server-verified provider (for example Cloudflare Turnstile or reCAPTCHA). A client-only checkbox is not used. Rate limits and lockout are the current abuse controls. |
| Profile photo | Gallery, camera, and crop | The cropped JPEG is stored in SQLite. Camera and photo-library permission prompts appear on iOS and Android. |

Session id is stored in shared preferences on this development build. Production should move that token to platform secure storage and keep authorization on a server, not in the Flutter binary.
