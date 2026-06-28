# Running ssr-miloco on Windows

Xiaomi Miloco **cannot run natively on Windows** — it needs a POSIX
network/camera-streaming stack. On Windows you run everything in **Docker**,
which is the default deployment path for ssr-miloco.

## 1. Install Docker Desktop

Install [Docker Desktop](https://www.docker.com/products/docker-desktop/) and
make sure it uses the **WSL 2 / Linux containers** backend (the default).

## 2. Start the stack

From a PowerShell prompt in the cloned repo:

```powershell
Copy-Item .env.example .env      # then edit .env to add your keys
docker compose up -d
```

This builds and starts:

- `miloco` — the Miloco dashboard + API on http://localhost:1810
- `ssr` — the SSR agent gateway (channel + Miloco activity→bus bridge)

## 3. One-time setup

```powershell
# Bind your Mi account to Miloco (follow the dashboard prompts).
docker compose exec miloco miloco-cli account bind

# Configure the SSR channel and the gateway record.
docker compose run --rm ssr channel config xiaomi
docker compose run --rm ssr gateway install home --channel xiaomi --no-start
docker compose restart ssr
```

## 4. Verify

```powershell
docker compose exec ssr ssr miloco status
docker compose exec ssr ssr miloco sync
docker compose logs -f ssr
```

## Note on the SSR gateway backend

The native Windows gateway service (**nssm** / **Scheduled Task**) is
**deprecated**. When you run `ssr gateway install` on Windows, SSR uses a
**Docker** backend by default: a container named `ssr-gateway-<name>` with
`--restart unless-stopped`, the host `~/.ssr` bind-mounted in, and
`MILOCO_BASE_URL` pointing at `host.docker.internal:1810`. If Docker is not
available it falls back to nssm (or a Scheduled Task). Manage it with:

```powershell
ssr gateway status home
docker logs -f ssr-gateway-home
```
