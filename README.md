# ssr-miloco

**ssr-miloco = [SSR Agent](https://github.com/NannaOlympicBroadcast/ssr-agent) ×
[Xiaomi Miloco](https://github.com/XiaoMi/xiaomi-miloco)** — a coding/assistant
agent that can also *perceive and act on your home*.

SSR is a command-line agent (Google ADK + Gemini) with an event bus, messaging
channels (Feishu / WeChat / XiaoAI speaker) and a retrieval context pool. Miloco
is Xiaomi's official open-source "perceptive home" gateway: it binds your Mi
account, turns Mi Home cameras into a whole-home sensor, recognises family
members, records meaningful **activities (events)**, and runs **automations**.

ssr-miloco wires the two together so the agent can:

- **Control & query Mi Home devices** through Miloco (no third-party MIoT MCP).
- **React to what happens at home** — every Miloco activity becomes a
  `miloco.activity.<type>` event on the SSR bus, so a handler agent can act on a
  person arriving, a sensor tripping, or a hazard being detected.
- **Reason over your real home** — devices, family members, recent events and
  automations are snapshotted into the agent's persistent context pool.

> This repository is the **deployment / distribution** layer: a Docker-first
> orchestration of `ssr` + `miloco`. The integration code itself lives in
> ssr-agent (`ssr/integrations/miloco.py`, `ssr/agent/tools_miloco.py`, the
> Miloco gateway/bus wiring).

---

## Platform support

| Platform | How to run |
| --- | --- |
| **macOS / Linux** | Miloco runs natively; run `ssr` natively or in Docker. |
| **Windows** | Miloco **cannot run natively** — run everything in **Docker** (the default here). The SSR gateway also defaults to a Docker backend on Windows. |

Miloco needs a POSIX network/camera-streaming stack, so on Windows it must run
inside a Linux container. ssr-miloco makes Docker the default deployment path so
Windows users get a working setup out of the box.

---

## Quick start (Docker — works on macOS / Linux / Windows)

```bash
git clone https://github.com/NannaOlympicBroadcast/ssr-miloco.git
cd ssr-miloco
cp .env.example .env          # add GEMINI_API_KEY, MIMO/Miloco model keys, etc.

# Build & start Miloco + the SSR agent gateway
docker compose up -d

# One-time: bind your Mi account to Miloco (follow the CLI prompts)
docker compose exec miloco miloco-cli account bind
#   the Miloco REST API / dashboard is published on http://localhost:1810/

# One-time: configure the SSR messaging channel (e.g. the XiaoAI speaker)
docker compose run --rm ssr channel config xiaomi

# Check the wiring
docker compose exec ssr ssr miloco status     # Miloco reachable? account bound?
docker compose exec ssr ssr miloco sync        # snapshot the home into context
```

The `ssr` service runs `ssr gateway run home`, which serves the configured
channel **and** starts the Miloco activity → bus bridge automatically.

### Windows

Install [Docker Desktop](https://www.docker.com/products/docker-desktop/), then
the same `docker compose up -d` works. See [docs/windows.md](docs/windows.md).
The native Windows gateway (nssm / Scheduled Task) is **deprecated** — the
gateway runs as a container `ssr-gateway-<name>` instead.

---

## Using it

Once running, the agent has these tools (and matching `ssr miloco …` CLI
subcommands):

| Tool | What it does |
| --- | --- |
| `miloco_status` | Is Miloco reachable / the Mi account bound? |
| `miloco_devices` | List Mi Home devices |
| `miloco_device_control` | Control a device (`{"siid":2,"piid":1,"value":true}`) |
| `miloco_family` | Recognised family members / persons |
| `miloco_activities` | Recent home events |
| `miloco_automations` | Automation rules |
| `miloco_sync` | Refresh the persistent home-context snapshot |

React to the home from a handler agent:

```text
当 miloco.activity.hazard.** 事件发生时，立刻给我发飞书提醒并描述画面。
(When a miloco.activity.hazard.* event fires, send me a Feishu alert describing the scene.)
```

SSR turns that into a `bus_create_handler` subscription on `miloco.activity.**`.

---

## Architecture

```
┌──────────────┐   activities (events)    ┌───────────────────────────┐
│ Xiaomi Miloco│ ───────────────────────▶ │ MilocoActivityBridge       │
│  (FastAPI)   │   /api/events            │  → miloco.activity.<type>  │
│ :1810        │ ◀───────────────────────  │     on the SSR bus         │
│ devices /    │   device control          └─────────────┬─────────────┘
│ persons /    │   /api/miot/...                          │ bus events
│ rules        │                                          ▼
└──────────────┘                            ┌───────────────────────────┐
        ▲  snapshot (sync)                   │ SSR Agent                  │
        └──────────────────────────────────▶ │  tools + context pool +    │
                                             │  channels (XiaoAI/Feishu)  │
                                             └───────────────────────────┘
```

See [docs/architecture.md](docs/architecture.md) for detail.

## Configuration

`MILOCO_BASE_URL` (default `http://miloco:1810` in compose, or
`http://host.docker.internal:1810` when Miloco runs on the host) tells SSR where
the Miloco API is. Per-install overrides live in `~/.ssr/miloco.json`
(`base_url`, `api_key`, `poll_interval`, `endpoints`). See `.env.example`.

## Credits & licensing

ssr-miloco orchestrates two upstream projects; please observe their licenses:

- **SSR Agent** — NannaOlympicBroadcast/ssr-agent
- **Xiaomi Miloco** — XiaoMi/xiaomi-miloco (non-commercial use; see its LICENSE)
