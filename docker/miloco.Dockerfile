# ssr-miloco — Xiaomi Miloco service image.
#
# Miloco (https://github.com/XiaoMi/xiaomi-miloco) runs natively on macOS/Linux
# only; this image is how it runs on Windows (and a clean way to run it
# anywhere). It clones Miloco and follows its documented install, then serves
# the dashboard + REST API on :1810.
#
# NOTE: Miloco is a uv workspace with a React dashboard and native camera libs;
# its build requirements evolve. This Dockerfile follows the upstream
# `scripts/install.sh` flow — pin MILOCO_REF and adjust to match the Miloco
# release you deploy. A multimodal model key (MiMo recommended) is required at
# runtime; pass it via the environment (MILOCO_OMNI_API_KEY) — see .env.example.
# Base image pulled from the docker.1ms.run mirror (faster/available in CN).
# Override with --build-arg BASE_IMAGE=python:3.11-slim to use Docker Hub.
ARG BASE_IMAGE=docker.1ms.run/library/python:3.11-slim
FROM ${BASE_IMAGE}

ENV PYTHONUNBUFFERED=1 \
    MILOCO_HOME=/root/.miloco

ARG MILOCO_REF=main
ARG MILOCO_REPO=https://github.com/XiaoMi/xiaomi-miloco.git

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        git ca-certificates curl build-essential \
    && rm -rf /var/lib/apt/lists/*

# uv drives the Miloco backend workspace.
RUN curl -LsSf https://astral.sh/uv/install.sh | sh
ENV PATH="/root/.local/bin:${PATH}"

WORKDIR /opt
RUN git clone --depth 1 --branch "${MILOCO_REF}" "${MILOCO_REPO}" miloco
WORKDIR /opt/miloco

# Follow upstream install (backend deps; the dev flag skips the heavier web build).
RUN bash scripts/install.sh --dev || \
    (cd backend/miloco && uv sync) || true

EXPOSE 1810

# Serve the dashboard + API on all interfaces so the SSR container can reach it.
# Adjust to the upstream CLI if it changes (e.g. `miloco-cli dashboard`).
CMD ["bash", "-lc", "miloco-cli dashboard --host 0.0.0.0 --port 1810 || (cd backend/miloco && uv run uvicorn miloco.main:app --host 0.0.0.0 --port 1810)"]
