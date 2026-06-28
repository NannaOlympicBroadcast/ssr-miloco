# ssr-miloco — Xiaomi Miloco service image.
#
# Miloco (https://github.com/XiaoMi/xiaomi-miloco) runs natively on macOS/Linux
# only; this image is how it runs on Windows (and a clean way to run it
# anywhere). It installs Miloco's workspace packages (the `miloco-miot`,
# `miloco` backend and `miloco-cli` CLI) so `miloco-backend` and `miloco-cli`
# are on PATH, then serves the REST API + dashboard on :1810.
#
# A multimodal model key (MiMo recommended) is required for Miloco's perception;
# pass it via the environment (MILOCO_OMNI_API_KEY) — see .env.example. Pin
# MILOCO_REF to the Miloco release you deploy.

# Base image pulled from the docker.1ms.run mirror (faster/available in CN).
# Override with --build-arg BASE_IMAGE=python:3.11-slim to use Docker Hub.
ARG BASE_IMAGE=docker.1ms.run/library/python:3.11-slim
FROM ${BASE_IMAGE}

ENV PYTHONUNBUFFERED=1 \
    MILOCO_HOME=/root/.miloco \
    PIP_NO_CACHE_DIR=1

ARG MILOCO_REF=main
ARG MILOCO_REPO=https://github.com/XiaoMi/xiaomi-miloco.git

# git for the clone (hatch-vcs reads it for the version); build-essential for any
# sdist that needs compiling; the libs the backend's wheels load at import time
# (opencv-python-headless / onnxruntime / av).
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        git ca-certificates build-essential \
        libgl1 libglib2.0-0 libgomp1 \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /opt
RUN git clone --depth 1 --branch "${MILOCO_REF}" "${MILOCO_REPO}" miloco
WORKDIR /opt/miloco

# Install the workspace packages onto PATH. Order matters: the backend depends
# on `miloco-miot` (backend/miot), so install that first; then the backend and
# the CLI. This exposes the `miloco-backend` and `miloco-cli` console scripts.
RUN pip install ./backend/miot \
    && pip install ./backend/miloco ./cli

# Bind on all interfaces so the SSR container can reach the API over the compose
# network (Miloco defaults to 127.0.0.1; env override is MILOCO_SERVER__HOST).
ENV MILOCO_SERVER__HOST=0.0.0.0 \
    MILOCO_SERVER__PORT=1810

EXPOSE 1810

# Run the backend API server in the foreground. Bind the Mi account / manage
# scope with:  docker compose exec miloco miloco-cli account bind
CMD ["miloco-backend"]
