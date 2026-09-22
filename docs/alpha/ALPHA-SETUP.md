# FITOS closed alpha — setup (Phase 6.6, Gate 6)

The alpha runs the whole stack on your own hardware:

```
Samsung S24 ──Wi-Fi──▶ http://<PC-LAN-IP>:8080 ──▶ Docker `fitos-api` ──▶ Docker `fitos-postgres`
                                                       │
                                                       ├─▶ Firebase Admin (verifies ID tokens)
                                                       └─▶ Gemini (GEMINI_API_KEY in docker/.env)
Phone ──▶ Firebase Auth (sign-in; public client config from --dart-define)
Phone ──▶ Health Connect (device-local; never sent to the API or the model)
```

Nothing below goes into Git: `docker/.env`, `apps/api/.secrets/`, and
`apps/mobile/alpha.env` are all gitignored.

## 1. Backend on the PC

```powershell
cd "D:\dev\fit new\docker"
docker compose up --build -d api
docker compose logs api | Select-String "ai:|listening"
# expect:  ai: configured   and   Server listening at http://172.18.0.x:8080 (the container's address; it listens on every interface)
```

`docker/.env` must hold `GEMINI_API_KEY` and `GEMINI_MODEL=gemini-3.6-flash`
(copy `docker/.env.example`). The Firebase service-account key sits in
`apps/api/.secrets/` (mounted read-only into the container).

The API is published on **all interfaces** (`0.0.0.0:8080`, compose
`ports: 8080:8080`), so the phone reaches it at the PC's Wi-Fi address.
Windows Firewall already allows inbound TCP for `com.docker.backend.exe`
on the *Public* profile (Docker Desktop's own rule); the Wi-Fi network on
this PC is classified Public, so no extra rule is needed. If the network is
ever reclassified Private, add an inbound rule for TCP 8080 (or for
`com.docker.backend.exe`) on the Private profile.

Check from the PC itself (this proves the listener, not the phone's path):

```powershell
Invoke-WebRequest -UseBasicParsing http://<PC-LAN-IP>:8080/health   # 200
```

## 2. `apps/mobile/alpha.env`

```
copy apps\mobile\alpha.env.example apps\mobile\alpha.env
```

Fill in the five Firebase values you already use with `--dart-define`
(same names), and leave `API_HOST=auto` — the build script picks the PC's
Wi-Fi IPv4 at build time (or write the address explicitly). `API_PORT`
defaults to 8080.

| key | where it comes from |
|---|---|
| `FIREBASE_API_KEY`, `FIREBASE_APP_ID`, `FIREBASE_MESSAGING_SENDER_ID`, `FIREBASE_PROJECT_ID` | Firebase console → Project settings → Your apps → Android |
| `GOOGLE_WEB_CLIENT_ID` | Authentication → Sign-in method → Google → *Web client ID* |
| `API_HOST` | `auto`, or the PC's LAN IP (`ipconfig` → Wi-Fi IPv4) |

## 3. Build / install / run

```powershell
cd "D:\dev\fit new\apps\mobile"
.\tool\alpha.ps1                 # debug APK  → build\app\outputs\flutter-apk\app-debug.apk
.\tool\alpha.ps1 -Install        # …and adb install -r onto the connected S24
.\tool\alpha.ps1 -Run            # flutter run on the S24 (hot reload, logs)
.\tool\alpha.ps1 -Release        # release-like APK (Gate 7)
.\tool\alpha.ps1 -ApiHostOverride 192.168.1.20   # one-off host
```

(`tool/alpha.sh` is the same for Git Bash / macOS / Linux.)

The script prints the resolved `API_BASE_URL` and the Firebase values
masked, then passes everything as `--dart-define` (`FLAVOR=alpha`,
`APP_VERSION`, `API_BASE_URL`, the Firebase five). It writes nothing to
disk besides the APK.

The phone must be on the **same Wi-Fi** as the PC (not mobile data, not a
guest network with client isolation).

## 4. What the build does with the host

- `API_BASE_URL` is the only place the host lives. `lib/core/config/env.dart`
  reads it; `android/app/build.gradle.kts` reads the same define (Flutter
  forwards `--dart-define` to Gradle) and **generates**
  `res/xml/network_security_config.xml` that permits cleartext HTTP for that
  one host only. Everything else stays HTTPS-only (`base-config
  cleartextTrafficPermitted="false"`). An `https://` base URL yields a
  config with no cleartext at all. No IP is committed anywhere.
- Without the define (a plain `flutter run`), the local default
  `http://10.0.2.2:8080` (emulator → host) applies, as before.
- The main manifest now declares `INTERNET` (Flutter's template grants it
  in debug/profile only) so release-like builds can reach the network.
- Profile shows a build line: `FITOS 1.0.0-alpha.1 · alpha · <host>`, and the
  sign-in screen shows `Backend <host:port> · FITOS <version>` in alpha builds.
- **The address is compiled in.** If the PC's LAN address changes — a different
  Wi-Fi, a new DHCP lease — the installed APK keeps calling the old one and the
  phone gets no answer at all. Rebuild after any address change. The build
  script now checks `/health` at the resolved address first and refuses to
  build when it does not answer (`-SkipHealthCheck` overrides).

## 5. Verify from the S24 (Gate 6 integration checks)

Use `docs/alpha/PHASE-6.6-ALPHA-CHECKLIST.md`, section A. In short:
open `http://<PC-LAN-IP>:8080/health` in the phone's browser (expect
`{"status":"ok"…}`), install the APK, sign in, and walk Home → Training →
a workout → AI.

## 6. Troubleshooting

| symptom | cause / fix |
|---|---|
| Sign-in hangs, then "Could not reach FITOS at `<host>`" | that address is what the APK was built with. If it is not the PC's current LAN IPv4 (`ipconfig`), the APK is stale: rebuild (`.	oollpha.ps1 -Install`). This is the Gate 6 failure of 2026-09-22: the PC changed networks after the APK was built. |
| Phone browser cannot open `/health` | different Wi-Fi, client isolation on the router, or the firewall (see §1). |
| App shows "Can't reach FITOS" on Home | same as above, or the API container is down (`docker compose ps`). |
| "Not set up on this server yet" on the AI tab | `GEMINI_API_KEY` missing in `docker/.env`; restart the container after editing. |
| "FITOS AI is busy right now" | the free tier allows **20 requests/day/model**; a paid tier is required for real testing. |
| Splash says Firebase is not configured | `alpha.env` values missing; the script refuses to build without the five. |
| Google sign-in fails | the debug keystore's SHA-1 must be registered on the Firebase Android app. |
