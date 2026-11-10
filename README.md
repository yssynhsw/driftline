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

## Gestion 2 — Voyages et itinéraires intelligents

Branch: `feature/voyages-itineraires`.

Includes trip CRUD, day-by-day itineraries, Gemini AI generation, Open-Meteo weather, budget analysis, schedule conflict detection, and a Spring Boot Gemini proxy for classmates.

### Prerequisites

- Flutter SDK (stable)
- JDK **17** (for the Gemini proxy)
- Windows PowerShell (scripts under `scripts/`)
- Optional: Android SDK / emulator or a physical device on the same Wi‑Fi

### Clone

```bash
git clone https://github.com/yssynhsw/driftline.git
cd driftline
git checkout feature/voyages-itineraires
flutter pub get
```

### Configure secrets (never commit)

```powershell
Copy-Item .env.local.example .env.local
# Edit .env.local — leave real values ONLY on your machine
```

| Variable | Purpose |
| --- | --- |
| `GEMINI_API_KEY` | Google AI Studio key (host PC / solo mode). **Never share.** |
| `DRIFTLINE_APP_TOKEN` / `GEMINI_APP_TOKEN` | Shared app token checked by the proxy (same value on host + clients) |
| `GEMINI_PROXY_URL` | Flutter → proxy URL (see below) |
| `GEMINI_MODEL` | Optional model id (default in example) |
| `PORT` | Proxy port (default `8080`) |

`.env.local`, `dart_defines.json`, and `dart_defines.proxy.json` are gitignored.

### Mode A — Solo (clé Gemini sur ta machine)

```powershell
.\scripts\sync_dart_defines.ps1
.\scripts\run_dev.ps1
```

Or VS Code / Cursor: **Driftline (Gemini local)**.

### Mode B — Proxy (recommandé en classe)

**PC hôte** (détient `GEMINI_API_KEY`) :

```powershell
.\scripts\run_backend.ps1
# optional helpers:
.\scripts\share_gemini_proxy.ps1
.\scripts\build_apk_lan.ps1
```

Health check: `http://127.0.0.1:8080/api/v1/gemini/health`

**Camarade / client** (pas de clé Gemini) :

1. Set in `.env.local`:
   - Emulator Android: `GEMINI_PROXY_URL=http://10.0.2.2:8080/api/v1/gemini/generate`
   - Phone / other PC (same Wi‑Fi): `GEMINI_PROXY_URL=http://<HOST_LAN_IP>:8080/api/v1/gemini/generate`
   - Same `GEMINI_APP_TOKEN` as the host
2. Run:

```powershell
.\scripts\run_dev_proxy.ps1
```

Or install the LAN APK built by the host. **Never put `GEMINI_API_KEY` in an APK.**

### SQLite

On first launch the app creates `driftline.db` (version 8) with users, trips, itinerary days/steps, and audit tables. No manual DB setup.

### Tests

```bash
flutter analyze lib test
flutter test
```

### More detail

- Proxy API: `backend/README.md`
- Soutenance notes: `docs/gestion2-soutenance.md`
