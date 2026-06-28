# ssr-miloco — Xiaomi Miloco service image (multi-stage).
#
# Miloco (https://github.com/XiaoMi/xiaomi-miloco) runs natively on macOS/Linux
# only; this image is how it runs on Windows (and a clean way to run it
# anywhere). It builds the React dashboard, folds it into the backend's static
# dir (so the wheel serves it — otherwise http://localhost:1810/ is 404), then
# installs the workspace packages so `miloco-backend` and `miloco-cli` are on
# PATH, and serves the REST API + dashboard on :1810.
#
# A multimodal model key (MiMo recommended) is required for Miloco's perception;
# pass it via the environment (MILOCO_OMNI_API_KEY) — see .env.example. Pin
# MILOCO_REF to the Miloco release you deploy.

# Base/Node images pulled from the docker.1ms.run mirror (faster/available in CN).
# Override with --build-arg BASE_IMAGE=python:3.11-slim / NODE_IMAGE=node:20-slim.
ARG BASE_IMAGE=docker.1ms.run/library/python:3.11-slim
ARG NODE_IMAGE=docker.1ms.run/library/node:20-slim

# ---- stage: source -----------------------------------------------------
# Clone once (keeps .git so hatch-vcs can derive a version) and share it.
FROM ${BASE_IMAGE} AS src
ARG MILOCO_REF=main
ARG MILOCO_REPO=https://github.com/XiaoMi/xiaomi-miloco.git
RUN apt-get update && apt-get install -y --no-install-recommends git ca-certificates \
    && rm -rf /var/lib/apt/lists/*
RUN git clone --depth 1 --branch "${MILOCO_REF}" "${MILOCO_REPO}" /opt/miloco

# ---- stage: web build --------------------------------------------------
# Build the React home dashboard (web/ → web/dist).
FROM ${NODE_IMAGE} AS web
COPY --from=src /opt/miloco /opt/miloco
WORKDIR /opt/miloco/web
RUN npm install -g pnpm \
    && CI=true pnpm install \
    && pnpm build

# ---- stage: final runtime ---------------------------------------------
FROM ${BASE_IMAGE}

ENV PYTHONUNBUFFERED=1 \
    MILOCO_HOME=/root/.miloco \
    PIP_NO_CACHE_DIR=1

# build-essential for any sdist; the libs the backend wheels load at import time
# (opencv-python-headless / onnxruntime / av).
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        git ca-certificates build-essential \
        libgl1 libglib2.0-0 libgomp1 \
    && rm -rf /var/lib/apt/lists/*

COPY --from=src /opt/miloco /opt/miloco
WORKDIR /opt/miloco

# Fold the built dashboard into the backend static dir so the wheel ships it
# (mirrors upstream scripts/build.sh::build_web). static_dir = <pkg>/static.
COPY --from=web /opt/miloco/web/dist/ /tmp/webdist/
RUN mkdir -p backend/miloco/src/miloco/static \
    && for item in index.html assets fonts favicon.svg watch.html vendor; do \
         if [ -e "/tmp/webdist/$item" ]; then cp -R "/tmp/webdist/$item" backend/miloco/src/miloco/static/; fi; \
       done \
    && rm -f backend/miloco/src/miloco/static/assets/*.map \
    && rm -rf /tmp/webdist

# Install the workspace packages onto PATH. Order matters: the backend depends
# on `miloco-miot` (backend/miot), so install that first; then the backend
# (now carrying the static dashboard) and the CLI.
RUN pip install ./backend/miot \
    && pip install ./backend/miloco ./cli

# Bind on all interfaces so the SSR container can reach the API over the compose
# network (Miloco defaults to 127.0.0.1; env override is MILOCO_SERVER__HOST).
ENV MILOCO_SERVER__HOST=0.0.0.0 \
    MILOCO_SERVER__PORT=1810

EXPOSE 1810

# Run the backend API server (serves the dashboard at / and the REST API at
# /api). Bind the Mi account with:
#   docker compose exec miloco miloco-cli account bind
CMD ["miloco-backend"]
