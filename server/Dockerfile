# Base pinned to >= 22.23.4 for CVE-2026-111497 (Node2Shell, Brotli decoder OOB write).
# ── Stage 1: install deps (cached layer) ──────────────────────────
FROM node:22.23.4-slim@sha256:de170b39439eb0e5a3444ad7d60b015614a381e10fecae2e30ec9e735122f38d AS deps
WORKDIR /app

# Copy only manifests so this layer is cached unless deps change.
COPY package.json package-lock.json ./
RUN npm ci --omit=dev --ignore-scripts

# ── Stage 2: production image ─────────────────────────────────────
FROM node:22.23.4-slim@sha256:de170b39439eb0e5a3444ad7d60b015614a381e10fecae2e30ec9e735122f38d AS runtime

# Run as a non-root user for least-privilege.
RUN groupadd --system app && useradd --system --gid app --home-dir /app app

WORKDIR /app

# Copy installed node_modules from the deps stage.
COPY --from=deps /app/node_modules ./node_modules

# Copy application source.
COPY package.json package-lock.json ./
COPY src/ ./src/

# Switch to non-root user.
USER app

# Expose the HTTP+WS port (env-configurable, default 3000).
EXPOSE 3000

# Node production tuning.
ENV NODE_ENV=production

# Docker healthcheck hitting /healthz every 30s.
HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
  CMD node -e "fetch('http://127.0.0.1:'+(process.env.PORT??3000)+'/healthz').then(r=>process.exit(r.ok?0:1)).catch(()=>process.exit(1))"

# Start the server.
CMD ["node", "src/server.js"]
