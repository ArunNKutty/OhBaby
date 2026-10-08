# Oh baby baby!

A baby feeding log for breastfeeding and bottles (formula or expressed breast milk). Parents can log a feed with poor signal, look back through the day, and see the week. The screens and palette come from [Baby-Feed-Tracker](https://github.com/ArunNKutty/Baby-Feed-Tracker) (`claude/baby-feeding-tracker-flutter-b7xjtc`). This repo follows the technical design: one Flutter codebase and one Go API that is the only writer of a DuckDB file.

This slice is the installable web app, on-device storage, and the API behind it (Google sign-in, feeding sync, the week summary, and first-party usage events). App Store and Play builds, push reminders, and partner invites are later.

## Layout

```
app/       Flutter client (web, and the same code for iOS and Android later)
server/    Go 1.27 API, JSON under /v1, DuckDB
deploy/    cloudflared example for a Mac
scripts/   mac-serve.sh builds the web app and serves it with the API
```

Feeding changes go through `FeedingRepository`. The app keeps a local drift database (SQLite; on the web that is the WASM build in IndexedDB) and an outbox. Signing in is optional. Until you sign in, nothing leaves the device.

## Run it here

You need Flutter 3.47 (stable) and Go 1.27 with cgo (a C compiler). DuckDB is linked through `github.com/duckdb/duckdb-go/v2`.

Terminal 1, the API:

```bash
cd server
CGO_ENABLED=1 go run ./cmd/api
```

It listens on `http://127.0.0.1:47220`. `GET /healthz` returns `{"status":"ok","duckdb":"ok"}`.

Terminal 2, the web app:

```bash
cd app
flutter pub get
dart run build_runner build
flutter run -d web-server --web-hostname 0.0.0.0 --web-port 47219 --no-web-resources-cdn
```

Open `http://127.0.0.1:47219`. CanvasKit and the Nunito font are served with the app, not from a Google CDN.

Log a feeding without an account. Today is empty until you add one. Swipe left to delete, then undo. The Week tab averages finished days in the current week.

## Google sign-in

Customer login is Sign in with Google. The API does not ship with a client id or secret. Leave them unset and the feeding log still works. Account then explains what is missing.

In Google Cloud Console, create an OAuth client of type **Web application** and set:

| Name | Value |
| --- | --- |
| `GOOGLE_CLIENT_ID` | The client id from that OAuth client |
| `GOOGLE_CLIENT_SECRET` | The client secret from that OAuth client |

Register every redirect URI you will actually use. The server sends exactly one, from `GOOGLE_REDIRECT_URI`:

| How you run it | `GOOGLE_REDIRECT_URI` |
| --- | --- |
| Flutter on port 47219 and the API on 47220 | `http://127.0.0.1:47220/v1/auth/google/callback` |
| `scripts/mac-serve.sh` (one process on port 47221) | `http://127.0.0.1:47221/v1/auth/google/callback` |
| The same process behind your tunnel | `https://YOUR_HOSTNAME/v1/auth/google/callback` |

Also set `OHBABY_APP_ORIGINS` and `OHBABY_ALLOWED_ORIGINS` to the origin you open in the browser (for the tunnel, `https://YOUR_HOSTNAME`). See `.env.example`.

Set `OHBABY_JWT_SECRET` to a long random string before anyone else can reach the server. The development default is only for a machine you control.

There is no email-code login. The technical design used email codes and no social login; sign-in here is Google, as requested. A later iOS build that offers Google sign-in also needs Sign in with Apple (App Store rule 4.8).

## Mac and Cloudflare Tunnel

The app is meant to run on your Mac. `cloudflared` on that Mac publishes it. This environment cannot log in to your Cloudflare account or open a browser on your Mac, so the tunnel itself is a step you run.

1. Install Flutter 3.47, Go 1.27, and a C compiler.
2. `brew install cloudflared`
3. `cloudflared tunnel login`  
   A browser opens. Log in and pick the hostname's zone. This writes `cert.pem` under `~/.cloudflared`.
4. `cloudflared tunnel create oh-baby-baby`  
   Note the tunnel UUID and the credentials file path.
5. Copy `deploy/cloudflared/config.example.yml` to `~/.cloudflared/config.yml`. Set `tunnel` and `credentials-file`. Leave `url` as `http://127.0.0.1:47221`.
6. `cloudflared tunnel route dns oh-baby-baby YOUR_HOSTNAME`  
   That creates a CNAME to `<UUID>.cfargotunnel.com`. Your domain's nameservers must already be on Cloudflare.
7. Register `https://YOUR_HOSTNAME/v1/auth/google/callback` on the Google OAuth client and export `GOOGLE_REDIRECT_URI` to that exact string. Add `https://YOUR_HOSTNAME` to `OHBABY_APP_ORIGINS` and `OHBABY_ALLOWED_ORIGINS`.
8. `./scripts/mac-serve.sh`
9. `cloudflared tunnel run oh-baby-baby`
10. `cloudflared tunnel info oh-baby-baby`

To keep the tunnel running after you log out, install it as a launch agent: [run as a service](https://developers.cloudflare.com/tunnel/features/locally-managed-tunnels/as-a-service/).

`scripts/mac-serve.sh` builds the web app with `--no-web-resources-cdn` and serves the API and the site on port 47221. Hashed CanvasKit files are cached for a long time. `index.html` and `flutter_bootstrap.js` are not.

On an iPhone, an installed web app does not share storage with the Safari tab. Sign in after Add to Home Screen so the server copy is the one that matters. The home-screen name is **Oh baby!**

## Checks

```bash
cd server && CGO_ENABLED=1 go vet ./... && CGO_ENABLED=1 go test ./...
cd app && flutter analyze && flutter test
```

## Cloudflare agent setup

Skills are installed for this agent at `~/.agents/skills` (from `npx skills add cloudflare/skills`). The project MCP entry is `.cursor/mcp.json` and points at `https://mcp.cloudflare.com/mcp`. OAuth for that server starts the first time a Cursor agent calls it. The `cf` CLI was not installed; say if you want it.

```
┌─ Cloudflare Agent Setup Complete ────────────────────┐
│  ✓ Skills  ~/.agents/skills                          │
│  ✓ MCPs    .cursor/mcp.json                          │
│                                                      │
│  ⚡ Restart your agent to load the MCP servers       │
└──────────────────────────────────────────────────────┘
```

## Still open

Hosting region, the public hostname, the Apple bundle id and Play application id, whether analytics should default on for EU and UK users (this build stays off until you turn it on in Account), which countries launch in, and whether to ask for a birth date. Nightly Parquet export to object storage is `Store.ExportParquet` and is not scheduled here. Disk encryption for the DuckDB file is part of how you host the Mac.
