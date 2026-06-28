#!/usr/bin/env bash
# ssr-miloco — bring up the stack (macOS / Linux). Windows: see docs/windows.md.
set -euo pipefail
cd "$(dirname "$0")/.."

if ! command -v docker >/dev/null 2>&1; then
  echo "Docker is required. Install Docker, then re-run." >&2
  exit 1
fi

if [ ! -f .env ]; then
  cp .env.example .env
  echo "Created .env from .env.example — edit it to add your keys, then re-run." >&2
  exit 1
fi

echo "Building & starting miloco + ssr…"
docker compose up -d --build

cat <<'EOF'

Up. One-time setup:
  docker compose exec  miloco miloco-cli account bind
  docker compose run --rm ssr channel config xiaomi
  docker compose run --rm ssr gateway install home --channel xiaomi --no-start
  docker compose restart ssr

Check:
  docker compose exec ssr ssr miloco status
  docker compose logs -f ssr
EOF
