# ─────────────────────────────────────────────────────────────────
#  Harbor Coding Benchmark – Mother Project
#  Base: mcr.microsoft.com/playwright:v1.45.0-jammy
#  All npm dependencies are installed at BUILD TIME so that the
#  container can run with --network none (fully air-gapped).
# ─────────────────────────────────────────────────────────────────
FROM mcr.microsoft.com/playwright:v1.45.0-jammy

# ── 1. System-level tools ─────────────────────────────────────────
RUN apt-get update && apt-get install -y --no-install-recommends \
      curl \
      sqlite3 \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# ── 2. Copy manifests first (layer-cache-friendly) ────────────────
COPY workspace/backend/package*.json   ./workspace/backend/
COPY workspace/frontend/package*.json  ./workspace/frontend/
COPY tests/package*.json               ./tests/

# ── 3. Install all Node dependencies at build time ────────────────
RUN cd workspace/backend  && npm ci --omit=dev
RUN cd workspace/frontend && npm ci
RUN cd tests              && npm ci

# Install Playwright browser binaries (Chromium only, bundled in base image)
RUN cd tests && npx playwright install chromium --with-deps || true

# ── 4. Copy full source ───────────────────────────────────────────
COPY workspace/ ./workspace/
COPY tests/     ./tests/
COPY environment/ ./environment/

# ── 5. Build frontend (produces workspace/frontend/dist/) ─────────
RUN cd workspace/frontend && npm run build

# ── 6. Create seed database from backend initialisation ──────────
#  Run db.js in "seed mode" to generate seed.db
RUN cd workspace/backend && node db.js --seed

# ── 7. Permissions ───────────────────────────────────────────────
RUN chmod +x /app/environment/bootstrap.sh /app/environment/teardown.sh

EXPOSE 3000 5173

CMD ["/app/environment/bootstrap.sh"]
