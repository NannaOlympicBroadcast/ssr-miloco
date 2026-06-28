# ssr-miloco architecture

ssr-miloco combines two upstream projects. The integration code lives in
**ssr-agent**; this repo packages and deploys the two together.

## Components

- **Xiaomi Miloco** (`miloco` service, port `1810`) — Xiaomi's perceptive home
  gateway. A FastAPI backend (all business routers mounted under `/api`) plus a
  React dashboard. It binds the Mi account, enumerates devices/homes, recognises
  family members (identity library), records *meaningful events* and runs
  *automation rules*. Relevant endpoints used by SSR:
  - `GET /health` — liveness probe (unauthenticated).
  - `GET /api/miot/status` — Mi-account bind status.
  - `GET /api/miot/device_list` — Mi Home devices.
  - `POST /api/miot/devices/{did}/control` — control a device.
  - `GET /api/miot/home` / `GET /api/miot/scenes` — homes and scenes.
  - `GET /api/identity/persons` — recognised family members.
  - `GET /api/events?since=<ms>&limit=<n>` — meaningful home events (activities).
  - `GET /api/rules` — automation rules.

- **SSR Agent** (`ssr` service) — the agent runtime. The Miloco integration
  (`ssr/integrations/miloco.py`) provides:
  - **A typed HTTP client** (`MilocoClient`) with the endpoints above, all
    overridable in `~/.ssr/miloco.json` so a new Miloco version can be pointed
    at without a code change.
  - **A bus event source** (`MilocoActivityBridge`) that streams `/api/events/stream`
    (**SSE**, real-time) and republishes each new activity as a
    `miloco.activity.<type>` event on the SSR bus, de-duplicated by activity id
    (state persisted under `~/.ssr/miloco/`). It falls back to polling
    `/api/events` when the stream is unavailable, and backfills any gap on every
    reconnect so no event is missed. Started automatically by `ssr gateway run`.
  - **Persistent context** — `ssr miloco sync` snapshots devices, family
    members, recent events and automations to `~/.ssr/miloco/snapshot.json`,
    which the context pool loads as retrievable REFS items.
  - **Agent tools** — `miloco_status`, `miloco_devices`, `miloco_device_control`,
    `miloco_family`, `miloco_activities`, `miloco_automations`, `miloco_sync`.

## Data flow

1. Miloco perceives the home and writes **activities** (events) + maintains
   device/identity/rule state.
2. The SSR gateway's bridge **streams** activities over SSE (polling fallback)
   and emits `miloco.activity.*` bus events in real time. Bus-handler agents
   (registered via `bus_create_handler`) fire a turn on matching events and can
   notify a channel, control a device, etc.
3. `ssr miloco sync` periodically snapshots the home so the agent reasons over
   current devices/people/rules without a live call.
4. Agent tools (or the user via a channel) call back into Miloco to query or
   **control** devices.

## Why Docker on Windows

Miloco needs a POSIX networking/camera-streaming stack and does not run natively
on Windows. ssr-miloco therefore runs Miloco (and the SSR gateway) in Linux
containers on Windows. The SSR gateway's service backend reflects this: on
Windows it defaults to a Docker container (`ssr-gateway-<name>`,
`--restart unless-stopped`) instead of the deprecated nssm / Scheduled-Task
service. Set `SSR_GATEWAY_BACKEND=docker` to force the Docker backend on any OS.
