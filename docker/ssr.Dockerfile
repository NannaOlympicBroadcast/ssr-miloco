# ssr-miloco — SSR Agent gateway image.
#
# Installs `ssr` (the SSR Agent, carrying the native Miloco integration) and
# runs it as a long-lived gateway: it serves a messaging channel and starts the
# Miloco activity → bus bridge. All mutable state lives under
# SSR_HOME=/data/.ssr (a volume), so credentials/tokens/sessions persist.
FROM python:3.11-slim

ENV PYTHONUNBUFFERED=1 \
    PIP_NO_CACHE_DIR=1 \
    PIP_DISABLE_PIP_VERSION_CHECK=1 \
    SSR_HOME=/data/.ssr

# Which ssr-agent ref to install (the branch/tag carrying the Miloco work).
ARG SSR_REF=claude/fervent-galileo-psbk39
ARG SSR_REPO=https://github.com/NannaOlympicBroadcast/ssr-agent.git

# Optional Node.js for the bundled chrome-devtools MCP plugin.
ARG INSTALL_NODE=false

RUN apt-get update \
    && apt-get install -y --no-install-recommends git ca-certificates \
    && if [ "$INSTALL_NODE" = "true" ]; then apt-get install -y --no-install-recommends nodejs npm; fi \
    && rm -rf /var/lib/apt/lists/*

RUN pip install "git+${SSR_REPO}@${SSR_REF}"

VOLUME ["/data"]

COPY docker/ssr-entrypoint.sh /usr/local/bin/ssr-miloco-entrypoint
# Strip any CR (defensive: if the file was checked out with CRLF on a Windows
# host, the shebang would otherwise be `bash\r`) and make it executable.
RUN sed -i 's/\r$//' /usr/local/bin/ssr-miloco-entrypoint \
    && chmod +x /usr/local/bin/ssr-miloco-entrypoint

# Reaches a host-run Miloco by default; compose overrides to the `miloco` service.
ENV MILOCO_BASE_URL=http://host.docker.internal:1810

# Invoke the entrypoint through bash explicitly (not via its shebang) so the
# image works even if the script slipped in with CRLF — the kernel never parses
# `#!/usr/bin/env bash\r`. The sed above also keeps the file body CR-free.
ENTRYPOINT ["bash", "/usr/local/bin/ssr-miloco-entrypoint"]
CMD ["gateway", "run", "home"]
