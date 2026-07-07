# Deploy Guide — Scythe Companion Server

This runbook walks you through deploying the Scythe Companion socket.io
server on a Linux VPS (Hostinger, DigitalOcean, Hetzner, etc.) using
Docker + Caddy for automatic TLS.

**You need:** a VPS with root access, a domain name pointing to the VPS
IP, and Docker installed. Total time: ~20 minutes.

---

## Architecture

```
Internet ──► :443 (HTTPS/WSS) ──► Caddy (TLS terminate)
                                    │
                                    ▼ :3000
                              Node server (socket.io)
```

- **Caddy** terminates TLS (auto Let's Encrypt) and reverse-proxies
  both HTTP and WebSocket traffic to the Node container.
- **Node server** runs as non-root inside its container, never exposed
  directly to the internet.
- **Port 443** is the only public port (80 is for the ACME challenge
  redirect, Caddy handles it).

---

## 1. Prerequisites on your VPS

### 1.1 Install Docker + Docker Compose

```bash
# Official install script (works on Ubuntu/Debian)
curl -fsSL https://get.docker.com | sh

# Verify
docker --version
docker compose version
```

### 1.2 DNS — point your domain to the VPS

Create an A record pointing your domain (e.g.
`scythe.yourdomain.com`) to the VPS public IP. Wait for DNS to propagate
(`dig scythe.yourdomain.com` should resolve to the VPS IP).

### 1.3 Firewall — expose only 80 + 443

```bash
# UFW (if enabled)
sudo ufw allow 22/tcp      # SSH
sudo ufw allow 80/tcp      # HTTP (Caddy ACME redirect)
sudo ufw allow 443/tcp     # HTTPS / WSS
sudo ufw enable
```

Do **NOT** open port 3000 — the Node server is internal to Docker only.

---

## 2. Get the code on the VPS

```bash
git clone https://github.com/Matos182/scythe-companion.git
cd scythe-companion
git checkout task/T2.5-docker-deploy   # or master once merged
```

---

## 3. Configure environment

Create a `.env` file in the repo root (next to `docker-compose.yml`):

```bash
cp server/.env.example server/.env
```

Edit `server/.env`:

```env
PORT=3000

# Your exact domain — Caddy needs this for the TLS cert.
# Example: https://scythe.yourdomain.com
CORS_ORIGIN=https://scythe.yourdomain.com

ROOM_TTL_HOURS=3
MIN_TURN_SEC=10
MAX_ROOMS=100
RATE_LIMIT_PER_MIN=20
MAX_CONNECTIONS_PER_IP=10
LOG_LEVEL=info
```

Then create the compose-level `.env` (just the domain for Caddy):

```bash
echo 'DOMAIN=scythe.yourdomain.com' > .env
```

---

## 4. Build and start

```bash
docker compose up -d --build
```

This will:
1. Build the Node server Docker image (multi-stage, non-root).
2. Start the Node server container.
3. Start Caddy, which obtains the TLS certificate on first request.
4. Caddy proxies `:443` → `server:3000`.

### Watch the logs

```bash
# Both services
docker compose logs -f

# Just the server
docker compose logs -f server

# Just Caddy (cert acquisition lives here)
docker compose logs -f caddy
```

Caddy may take 10–30 seconds to obtain the certificate. You'll see
"certificate obtained successfully" in the Caddy logs.

---

## 5. Verify the deployment

```bash
# Health check over HTTPS (from your laptop, not the VPS)
curl https://scythe.yourdomain.com/healthz
```

Expected response:

```json
{
  "status": "ok",
  "protocolVersion": 1,
  "uptime": 42,
  "rooms": 0,
  "activeTimers": 0,
  "maxRooms": 100
}
```

If you see a TLS warning: DNS hasn't propagated yet, or Caddy is still
obtaining the cert. Check `docker compose logs caddy`.

---

## 6. Point the Flutter app at the server

In the app (once T3.2 lands the settings screen), set the server URL to:

```
https://scythe.yourdomain.com
```

Use the HTTPS base URL in the app. The socket.io client starts from that
URL and upgrades the transport to secure WebSocket (`wss://`) through
Caddy; the same base URL is also used for the `/healthz` protocol check.

---

## 7. Update procedure (new version)

```bash
cd scythe-companion
git pull origin master
docker compose up -d --build
```

The `--build` flag rebuilds the image if the source changed. Existing
rooms are lost on restart (in-memory store, D2) — players just
rejoin with a room code.

### Rollback

```bash
git checkout <previous-commit>
docker compose up -d --build
```

---

## 8. LAN mode (fallback, no internet)

If you want to run a game on a local network without the VPS (e.g.
your laptop as the host):

```bash
cd server
npm ci
npm start
```

The server listens on `:3000`. The Flutter app connects via
`ws://<your-laptop-ip>:3000`. No TLS needed on LAN (D1 b/c).

---

## Troubleshooting

**Caddy can't get a certificate:**
- DNS not propagated? Check `dig +short yourdomain.com`.
- Port 80 blocked? Caddy needs :80 for the ACME HTTP challenge.
- Rate limited by Let's Encrypt? Wait an hour, check logs.

**`/healthz` returns 502:**
- Node container not ready? `docker compose logs server`.
- Healthcheck failing? `docker inspect scythe-server --format='{{.State.Health.Status}}'`.

**WebSocket connection refused:**
- Caddy handles WebSocket upgrade automatically. Check that your
  domain in `Caddyfile` matches the one the client connects to.
- CORS: `CORS_ORIGIN` in `server/.env` must match the app's origin
  (or `*` for testing).

**Port already in use:**
- Something on :80 or :443? `sudo ss -tlnp | grep -E ':(80|443)'`.
- Stop the conflicting service or change ports in `docker-compose.yml`.
