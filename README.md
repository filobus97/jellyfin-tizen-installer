# Jellyfin Tizen Installer

Docker-based build and deploy system for the [Jellyfin](https://jellyfin.org/) media client on Samsung Tizen TVs.

The container clones the upstream [jellyfin-web](https://github.com/jellyfin/jellyfin-web) and [jellyfin-tizen](https://github.com/jellyfin/jellyfin-tizen) repositories, builds a signed `.wgt` package, and installs it directly on the TV over the network. The only manual step is obtaining the Samsung certificates, which you do once and reuse for future updates.

---

## Prerequisites

### 1. Tizen IDE and Samsung Certificate

Download and install the **Tizen IDE** (tested on Windows; may work on Ubuntu).

From the Package Manager install:
- **Certificate Manager** — Main SDK tab → Tizen SDK Tools → Baseline SDK → Certificate Manager
- **Samsung Certificate Extension** — Extensions SDK tab → Extras → Samsung Certificate Extension

Then create the certificate:

1. Open the **Tizen Studio Device Manager**, click Remote Device Manager and connect to the TV.
2. Right-click the TV and click **Permit Install**.
3. If no valid certificate exists, you'll be prompted to open Certificate Manager:
   - Select the **Samsung** option (light blue background, two circles: Tizen left, Samsung right).
   - Follow the prompts to create a TV certificate.
   - Save the **Author Certificate password** — you'll use it as `CERT_PASSWORD` in `.env`.
   - When asked, choose **Apply the same password for the distributor certificate** (the container does not support different passwords for the two).
   - Select your TV's DUID from the list (it should appear automatically if the TV is connected).
4. After creation, the IDE shows the certificate directory (on Windows: `C:\Users\<username>\SamsungCertificate\<profilename>\`). Copy `author.p12` and `distributor.p12` into the `certs/` folder.
5. Retry **Permit Install** to confirm the certificate works.

### 2. Enable Developer Mode on the TV

In the TV settings, enable Developer Mode and set the IP of the machine you'll use for installation.

### 3. Docker and Docker Compose

Ensure Docker and Docker Compose are installed on the build machine.

---

## Project Structure

```
jellyfin-tizen/
├── certs/
│   ├── author.p12
│   └── distributor.p12
├── tizen-profile/
│   └── profiles.xml
├── compose.yml
├── example.env
├── .env              # your personal config (gitignored)
├── Dockerfile
├── entrypoint.sh
└── jellyfin-tizen-build.sh
```

---

## Configuration

Copy `example.env` to `.env` and fill in your values:

```bash
cp example.env .env
```

| Variable | Description |
|---|---|
| `TV_IP` | IPv4 address of the Samsung TV on the local network |
| `CERT_PASSWORD` | Password used for both author and distributor certificates |
| `LANG` / `LANGUAGE` / `LC_ALL` | Locale settings — run `locale` to check your system values |
| `TZ` | Timezone — see [tz database](https://en.wikipedia.org/wiki/List_of_tz_database_time_zones) |
| `JELLYFIN_TIZEN_RELEASE` | Branch of `jellyfin/jellyfin-tizen` to build (default: `master`) |
| `JELLYFIN_WEB_RELEASE` | Branch/tag of `jellyfin/jellyfin-web` to build (default: `release-10.10.z`) |
| `TIZEN_STUDIO_VERSION` | Tizen Studio version to install (default: `5.5`) |

---

## Usage

```bash
# Build the image and run the full pipeline (build + deploy to TV)
docker compose up --build

# Remove the container when done
docker compose down
```

The container is ephemeral: it builds, deploys to the TV, copies the `.wgt` artifact to `/result`, and exits.

### Saving the build artifact

To retain `Jellyfin.wgt` for manual installation without rebuilding, uncomment the volume in `compose.yml`:

```yaml
# volumes:
#   - /path/to/jellyfin-build-result:/result
```

---

## Notes

- Tizen Studio 5.5 is used — version 6.0 has known issues.
- Both certificates **must share the same password**.
- The `tizen-profile/profiles.xml` is a template; the container substitutes `${CERT_PASSWORD}` at runtime via `envsubst`.
- If you need to install to more than one TV, you can build once (saving `/result` via volume) and run `tizen install` manually for each device.

---

## Dependency versions (as of 2026-03-16)

The Dockerfile uses `ubuntu:latest` and `npm@latest` intentionally — no maintenance needed, always pulls the most recent versions. If a future build breaks, pin these explicitly in the Dockerfile:

| Dependency | Version at 2026-03-16 | Where to pin |
|---|---|---|
| Ubuntu base image | 24.04 LTS (Noble Numbat) | `FROM ubuntu:24.04` |
| Node.js (via NodeSource LTS) | v22.x | `setup_22.x` in the `curl \| bash` line |
| npm | 10.x | `npm install -g npm@10` in the Dockerfile — jellyfin-web ≥10.11.z requires `<11.0.0` |
| Tizen Studio | 5.5 | `TIZEN_STUDIO_VERSION=5.5` in `.env` (already pinned) |

---

*Personal project — not affiliated with Jellyfin or Samsung.*
