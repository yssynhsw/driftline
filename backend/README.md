# Driftline Gemini Proxy (Spring Boot)

Secure backend for Voyages & Affaires. The Flutter APK never embeds `GEMINI_API_KEY`.

## Endpoints

- `GET /api/v1/gemini/health` — readiness (no secrets)
- `POST /api/v1/gemini/generate` — proxy to Google Gemini
- `GET /actuator/health` — process health

### Request body

```json
{
  "prompt": "optional free-form prompt",
  "model": "gemini-3.5-flash",
  "request": { "contents": [], "generationConfig": {} }
}
```

Flutter sends the full Gemini `request` payload built by `GeminiItineraryGenerator`.

### Auth

When `DRIFTLINE_APP_TOKEN` is set, clients must send:

`X-Driftline-Token: <token>`

or `Authorization: Bearer <token>`.

### Rate limit

Default: 12 requests / minute / client IP (or app token).

## Local run

From repo root:

```powershell
.\scripts\run_backend.ps1
```

Requires `.env.local` with `GEMINI_API_KEY` (and ideally `DRIFTLINE_APP_TOKEN`).
The server listens on `0.0.0.0` so phones on the same Wi‑Fi can reach it.

## Classroom / camarades (same Wi‑Fi)

Do **not** share `GEMINI_API_KEY`. Share only the APK.

```powershell
# Sets GEMINI_PROXY_URL to your PC LAN IP and prints URLs
.\scripts\share_gemini_proxy.ps1

# Terminal 1 — keep running
.\scripts\run_backend.ps1

# Terminal 2 — APK without the Gemini API key
.\scripts\build_apk_lan.ps1
```

APK path: `build/app/outputs/flutter-apk/app-release.apk`

Flutter debug against the proxy (no key in the process):

- VS Code / Cursor: **Driftline (Gemini proxy — camarades)**
- or `.\scripts\run_dev_proxy.ps1`

## Deploy

1. Build jar: `.\mvnw.cmd -DskipTests package`
2. Set env vars on the host: `GEMINI_API_KEY`, `DRIFTLINE_APP_TOKEN`, optional `PORT`
3. Run: `java -jar target/gemini-proxy-0.0.1-SNAPSHOT.jar`
4. Expose HTTPS publicly (Render, Railway, Fly.io, Cloud Run, VPS + reverse proxy)
5. Build the APK with `.\scripts\build_apk_proxy.ps1` (public `GEMINI_PROXY_URL`)
