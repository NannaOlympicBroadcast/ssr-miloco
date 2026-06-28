#!/usr/bin/env bash
# Entrypoint for the ssr-miloco SSR gateway container.
#
# Scaffolds ~/.ssr (idempotent), then runs `ssr <args>`. If asked to run a
# gateway that hasn't been configured yet, it prints clear one-time-setup
# guidance and idles instead of crash-looping — so `docker compose up` is safe
# before you've configured a channel.
set -euo pipefail

ssr init >/dev/null 2>&1 || true

# Detect "gateway run <name>" with no matching gateway record and guide the user.
if [ "${1:-}" = "gateway" ] && [ "${2:-}" = "run" ]; then
  name="${3:-home}"
  if ! ssr gateway list 2>/dev/null | grep -q "\b${name}\b"; then
    cat <<EOF
[ssr-miloco] 网关 '${name}' 尚未配置 (gateway '${name}' is not configured yet).

请先完成一次性设置 (one-time setup):
  docker compose run --rm ssr channel config xiaomi
  docker compose run --rm ssr gateway install ${name} --channel xiaomi --no-start
  docker compose exec  miloco miloco-cli account bind

完成后重启本服务 (then restart this service):
  docker compose restart ssr

容器将保持空闲，避免崩溃重启循环 (idling to avoid a crash loop)…
EOF
    # Idle but stay alive so logs/exec remain available.
    exec tail -f /dev/null
  fi
fi

exec ssr "$@"
