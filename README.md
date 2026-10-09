# Oh baby baby!

A baby feeding log for breastfeeding and bottles (formula or expressed breast milk). Parents can log a feed with poor signal, look back through the day, and see the week. The screens and palette come from [Baby-Feed-Tracker](https://github.com/ArunNKutty/Baby-Feed-Tracker) (`claude/baby-feeding-tracker-flutter-b7xjtc`). This repo follows the technical design: one Flutter codebase and one Go API that is the only writer of a DuckDB file.

This slice is the installable web app, on-device storage, and the API behind it (Google sign-in, feeding sync, the week summary, and first-party usage events). App Store and Play builds, push reminders, and partner invites are later.

## Layout

```
app/       Flutter client (web, and the same code for iOS and Android later)
server/    Go 1.27 API, JSON under /v1, DuckDB
deploy/    nginx and the Railway DuckDB image
scripts/   local web and API scripts
```

Feeding changes go through `FeedingRepository`. The app keeps a local drift database (SQLite; on the web that is the WASM build in IndexedDB) and an outbox. Signing in is optional. Until you sign in, nothing leaves the device.

## Docker Compose

The container install is three services. The phone or browser keeps its own SQLite log (Drift). The shared database is a separate DuckDB server.

- `web` is the Flutter release bundle behind nginx.
- `duckdb` is the official `duckdb/duckdb` image ([Docker operations](https://duckdb.org/docs/lts/operations_manual/duckdb_docker)): the CLI runs with the database directory mounted at `/workspace`. It starts DuckDB's Quack server and stays open because the CLI is interactive. The file is `/workspace/ohbaby.duckdb` on the volume `ohbaby-data`. Several API processes can connect to this one server. Quack listens on port 9494 inside the container network and is not published on the host. The image tag on that page is current DuckDB (1.5.6), which is the release that includes Quack.
- `api` does not open the database file. It sends SQL to the DuckDB server. The phone's SQLite log is unchanged. DuckDB 1.5.6's `ATTACH` does not register the remote catalog, so the API uses `quack_query` instead.

Set `DUCKDB_QUACK_TOKEN` in `.env` before you share the server. The development default is not safe to share.

```bash
docker compose up --build
```

Open `http://127.0.0.1:47221`. nginx serves the site and proxies `/v1` and `/healthz` to the API on the same container network. Put Firebase and `OHBABY_JWT_SECRET` in a `.env` file next to `docker-compose.yml` (see `.env.example`) before you share the server. The public site is the Railway deploy below, not this local port.

## Railway

Railway is how this ships. It does not run `docker-compose.yml`. Create one empty Railway project, then add three services from the GitHub repository that contains this code. Select branch `cursor/railway-deploy-2188`. The prototype at [Baby-Feed-Tracker](https://github.com/ArunNKutty/Baby-Feed-Tracker) is the screen source. Linking that prototype branch deploys the old Flutter app, not the API or DuckDB.

In the project, choose **+ New → GitHub Repo** three times, same repository and branch `cursor/railway-deploy-2188`:

| Service name | Dockerfile variable | Public domain | Volume |
| --- | --- | --- | --- |
| `duckdb` | `RAILWAY_DOCKERFILE_PATH=deploy/railway/duckdb.Dockerfile` | none | mount path `/workspace` |
| `api` | `RAILWAY_DOCKERFILE_PATH=Dockerfile` | none | none |
| `web` | `RAILWAY_DOCKERFILE_PATH=deploy/railway/Dockerfile.web` | Generate Domain | none |

The service names have to stay `duckdb`, `api`, and `web`. Private DNS is `duckdb.railway.internal` and `api.railway.internal`.

On `duckdb` and `api`, set the same `DUCKDB_QUACK_TOKEN` (letters, numbers, dots, and dashes, 4 to 128 characters). Do not use `dev-only-not-for-production`. The DuckDB image refuses to start with that value. On `api`, also set `OHBABY_JWT_SECRET` to a long random string.

`api` variables:

```
OHBABY_ADDR=:47220
OHBABY_DB=quack:duckdb.railway.internal:9494
OHBABY_ALLOWED_ORIGINS=https://YOUR_WEB_DOMAIN
OHBABY_APP_ORIGINS=https://YOUR_WEB_DOMAIN
```

`YOUR_WEB_DOMAIN` is the hostname Railway shows after **Generate Domain** on `web`, with no path. Add that hostname, without `https://`, to Firebase Authentication → Settings → Authorized domains, and set the `FIREBASE_*` variables from `.env.example` on the `api` service.

`web` variable:

```
API_UPSTREAM=api.railway.internal:47220
```

Leave `PORT` unset. Railway sets it, and nginx listens on it. Only `web` should have a public domain. DuckDB stays on port 9494 inside the project.

`.railway/railway.ts` describes the same three services, the volume, and those non-secret variables. After `railway login` and `railway link`, install the SDK with `npm install railway` and run `railway config apply`. Set the token, JWT secret, and Firebase values in the dashboard. They are not in the file.

## Run it here

You need Flutter 3.47 (stable) and Go 1.27 with cgo (a C compiler). DuckDB is linked through `github.com/duckdb/duckdb-go/v2`.

Fast path (one terminal — recommended):

```bash
./scripts/dev-web-release.sh
```

This builds a **release** web app, then serves the UI and API together on **http://127.0.0.1:47219** with gzip and long-lived cache headers on CanvasKit/WASM. The HTML shell paints immediately; the Flutter UI appears as soon as the engine loads, while the local database opens in the background.

API-only on port 47220 (optional, for backend work):

```bash
cd server
CGO_ENABLED=1 go run ./cmd/api
```

Open `http://127.0.0.1:47219`. CanvasKit and the Nunito font are served with the app, not from a Google CDN. Use debug `flutter run` without `--release` only when you need hot reload.

`./scripts/mac-serve.sh` is the same one-process serve on port 47221, for a machine that already has Flutter and Go. It is not the public deploy.

Log a feeding without an account. Today is empty until you add one. Swipe left to delete, then undo. The Week tab averages finished days in the current week.

## Sign in with Google (Firebase)

Customer login is Sign in with Google through **Firebase Authentication**. The feeding log runs with these unset. Account then lists exactly what is missing. Do not invent the values.

In the [Firebase console](https://console.firebase.google.com/):

1. Create or open a project.
2. Authentication → Sign-in method → enable **Google**.
3. Authentication → Settings → Authorized domains: add `localhost`, `127.0.0.1`, and the Railway web hostname (no `https://`, no port).
4. Project settings → Your apps → add a **Web** app and copy its config.

| Name | Value |
| --- | --- |
| `FIREBASE_API_KEY` | `apiKey` |
| `FIREBASE_AUTH_DOMAIN` | `authDomain` |
| `FIREBASE_PROJECT_ID` | `projectId` |
| `FIREBASE_APP_ID` | `appId` |
| `FIREBASE_MESSAGING_SENDER_ID` | `messagingSenderId` |
| `FIREBASE_STORAGE_BUCKET` | `storageBucket`, if the config includes one |

The browser asks Firebase to sign in with Google, then sends the Firebase ID token to `POST /v1/auth/firebase/exchange`. The Go API checks that token and issues its own session. The web config is public in the page; it is still yours to provide.

Also set `OHBABY_APP_ORIGINS` and `OHBABY_ALLOWED_ORIGINS` to the origin you open in the browser. For Railway that is `https://` plus the web service hostname. See `.env.example`.

Set `OHBABY_JWT_SECRET` to a long random string before anyone else can reach the server. The development default is only for a machine you control.

There is no email-code login. A later iOS build that offers Google sign-in also needs Sign in with Apple (App Store rule 4.8).

On an iPhone, an installed web app does not share storage with the Safari tab. Sign in after Add to Home Screen so the server copy is the one that matters. The home-screen name is **Oh baby!**

## Checks

```bash
cd server && CGO_ENABLED=1 go vet ./... && CGO_ENABLED=1 go test ./...
cd app && flutter analyze && flutter test
```

## Still open

The Railway web hostname, the Apple bundle id and Play application id, whether analytics should default on for EU and UK users (this build stays off until you turn it on in Account), which countries launch in, and whether to ask for a birth date. Nightly Parquet export to object storage is `Store.ExportParquet` and is not scheduled here.
