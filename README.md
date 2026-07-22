# minecraft-server
![License](https://img.shields.io/github/license/MarvelCollin/minecraft-server) ![Last commit](https://img.shields.io/github/last-commit/MarvelCollin/minecraft-server) ![Docker](https://img.shields.io/badge/docker-ready-2496ED?logo=docker&logoColor=white)

A self-hosted, Dockerized Minecraft server with automated backups, ready to be exposed to the public internet.

## Requirements

- Docker
- Docker Compose
- Git Bash or WSL (Windows), to run `scripts/setup.sh`

## Quick Start

1. Run the setup script. It creates `.env` from the template and generates a random `RCON_PASSWORD` for you:

   ```
   bash scripts/setup.sh
   ```

2. (Optional) Open `.env` and adjust `MOTD`, `DIFFICULTY`, `GAME_MODE`, `WHITELIST`, `OPS`, etc. The defaults work as-is.

3. Start the server:

   ```
   docker compose up -d
   ```

4. Check the logs until the server reports "Done":

   ```
   docker compose logs -f minecraft
   ```

`docker compose up` refuses to start with a clear error if `.env` is missing or `RCON_PASSWORD` was never set, instead of silently running RCON with a blank password.

The world data is stored in `./data` and backups are stored in `./backups`, both on your host machine.

## Configuration

All settings are controlled through `.env`. See `.env.example` for the full list. Common ones:

| Variable | Description | Default |
|---|---|---|
| `SERVER_PORT` | Host port mapped to the server | `25565` |
| `SERVER_TYPE` | Server software (`VANILLA`, `PAPER`, `FABRIC`, `FORGE`, ...) | `VANILLA` |
| `SERVER_VERSION` | Minecraft version | `LATEST` |
| `SERVER_MEMORY` | Memory allocated to the JVM heap | `4G` |
| `CONTAINER_MEMORY_LIMIT` | Hard memory cap for the container | `5G` |
| `DIFFICULTY` | `peaceful`, `easy`, `normal`, `hard` | `normal` |
| `GAME_MODE` | `survival`, `creative`, `adventure`, `spectator` | `survival` |
| `KEEP_INVENTORY` | Players keep their items on death | `false` |
| `MOB_GRIEFING` | Mobs can break/pick up blocks (creepers, endermen, etc.) | `true` |
| `FIRE_SPREAD_RADIUS` | Max blocks fire can spread from a player. `-1` unlimited, `0` disables spread entirely | `-1` |
| `DAYLIGHT_CYCLE` | Time advances instead of staying fixed | `true` |
| `MOTD` | Description players see in their multiplayer list | `A Minecraft Server` |
| `SERVER_ICON` | URL or local path to a server icon image | (empty) |
| `MAX_PLAYERS` | Maximum concurrent players | `20` |
| `VIEW_DISTANCE` | Chunk render distance, in chunks | `8` |
| `SIMULATION_DISTANCE` | Chunk simulation (tick/mob AI) distance, in chunks | `6` |
| `ENABLE_WHITELIST` | Restrict join access to `WHITELIST` | `false` |
| `WHITELIST` | Comma-separated usernames allowed to join | (empty) |
| `OPS` | Comma-separated usernames granted operator | (empty) |
| `MODS` | Comma-separated mod download URLs (alternative to `mods.txt`) | (empty) |
| `REMOVE_OLD_MODS` | Remove previously downloaded mods before re-downloading on startup | `false` |
| `MODRINTH_PROJECTS` | Comma-separated Modrinth slugs (e.g. `sodium,lithium`) | (empty) |
| `MODRINTH_DOWNLOAD_DEPENDENCIES` | Auto-download mod dependencies: `required`, `optional`, `none` | `required` |
| `RCON_PASSWORD` | Password for remote console access | (required) |
| `BACKUP_INTERVAL` | How often the backup service runs | `6h` |
| `BACKUP_RETENTION_DAYS` | How long backups are kept | `7` |
| `PLAYIT_SECRET_KEY` | Auth key for the optional `playit` tunnel service | (empty, required only for the `playit` profile) |

Full list of supported variables: https://docker-minecraft-server.readthedocs.io/en/latest/variables/

## Mods

Mods require a mod loader. Before adding any mods, set `SERVER_TYPE` in `.env` to `FORGE` or `FABRIC` (vanilla does not support mods):

```
SERVER_TYPE=FABRIC
```

Then recreate the container (`docker compose up -d`) so it installs the mod loader before adding mods.

### Interactive mod manager

Run the built-in mod manager for a guided menu:

```
bash scripts/mods.sh
```

```
  ╔════════════════════════════════════════╗
  ║        Minecraft Mod Manager           ║
  ╚════════════════════════════════════════╝

  1) Add mod by URL          any download link
  2) Add mod from Modrinth   by slug name
  3) Add mod from file       drop .jar into mods/
  4) List all mods
  5) Remove a mod
  6) Exit
```

### Option 1: Add by URL

Works with any download link — Modrinth, CurseForge, GitHub releases, or any direct `.jar` URL. The menu lets you paste multiple URLs one per line:

```
bash scripts/mods.sh
# select 1, then paste URLs, press Enter on an empty line to finish
```

Or use the CLI directly for scripting:

```
bash scripts/mods.sh add https://cdn.modrinth.com/data/.../sodium-0.6.jar https://cdn.modrinth.com/data/.../lithium-0.14.jar
```

URLs are stored in `mods.txt` (one per line). The server downloads them automatically on startup.

### Option 2: Add from Modrinth

Type Modrinth project slugs (the short name in the URL, e.g. `modrinth.com/mod/sodium` → `sodium`). The server auto-resolves the correct version for your `SERVER_VERSION` and `SERVER_TYPE`:

```
bash scripts/mods.sh
# select 2, then type: sodium lithium starlight
```

Or set them directly in `.env`:

```
MODRINTH_PROJECTS=sodium,lithium,starlight
```

Dependencies are downloaded automatically by default (`MODRINTH_DOWNLOAD_DEPENDENCIES=required`).

### Option 3: Add from file

If you already have `.jar` files downloaded from any source:

1. Drop them into the `mods/` folder.
2. Run `bash scripts/mods.sh`, select option 3.
3. The script copies them into `data/mods/` where the server reads them.

### Applying changes

After adding or removing mods, restart the server:

```
docker compose restart minecraft
```

### Listing and removing mods

```
bash scripts/mods.sh list
```

Shows all mods from every source (URL mods in `mods.txt`, Modrinth slugs in `.env`, and local `.jar` files in `data/mods/`).

To remove, run the manager and select option 5 — it shows a numbered list across all sources and lets you pick which to remove.

## Exposing the Server Publicly

There are two ways to let people join over the internet. Which one works depends on whether your ISP gives you a real public IP or hides you behind CGNAT (common on residential/mobile plans) — check by comparing your router's WAN IP (its admin page, usually `192.168.0.1` or `192.168.1.1`) to what an external "what is my ip" search shows you. If they match, either option works; if they don't match, only Option A works.

### Option A: playit.gg (easiest, works behind CGNAT, no router changes)

This project includes an optional `playit` service using the [official playit-agent Docker image](https://github.com/playit-cloud/playit-agent). It makes an outbound-only connection to playit's relay, so it needs no port forwarding and works even behind CGNAT.

1. Go to [playit.gg](https://playit.gg/) and sign up.
2. Start their Docker agent setup wizard, give the agent a name, and copy the `SECRET_KEY` it generates.
3. Put it in `.env`:

   ```
   PLAYIT_SECRET_KEY=<your key>
   ```

4. Start it (it won't run as part of the normal `docker compose up -d` since it's an optional profile):

   ```
   docker compose --profile playit up -d
   ```

5. Verify your email if playit asks for it. Until you do, the agent connects but tunnels won't actually work — check your inbox for the verification link.
6. In the playit.gg dashboard, go to **Tunnels → New Tunnel** and fill in:
   - **Name your tunnel**: anything
   - **Tunnel Type**: `Minecraft Java`
   - **Public Endpoint**: leave on `Free Network` (the map underneath is informational, nothing to click)
   - **Assign to Agent**: select the agent you named in step 2
   - **Origin Config → Local IP**: `minecraft` — just the service name, no port. There's a separate field for the port; don't put it in both.
   - **Local Port**: `25565`
   - **Proxy Protocol**: `None`
7. Finish the wizard. playit.gg assigns a working address like `something.joinmc.link` — share that with players.

Custom domains aren't available on playit's free tier (Docker agent + one subdomain is free; a custom domain needs Playit Premium). If you want your own domain for free, use Option B instead.

### Option B: port forwarding + your own domain (needs a real public IP)

1. **Give your PC a static local IP** on your router (DHCP reservation), so port forwarding keeps working after reboots.
2. **Port forward** `25565/tcp` on your router to that local IP. Minecraft Java Edition only uses TCP, so UDP forwarding isn't needed.
3. Share `your-public-ip:25565` with players to test before bothering with a domain.

## Using a Domain

Only relevant if you're on Option B above (playit.gg's free tier uses its own `joinmc.link` subdomain instead). Unlike the rest of this README, these steps are standard DNS practice but haven't been tested end-to-end against a real registrar in this setup — the port-forward and playit.gg paths above were both actually run and externally verified, this one wasn't:

1. Buy a domain from any registrar.
2. Add a `SRV` record for `_minecraft._tcp` pointing to your host, so players can join with just `play.yourdomain.com` without a port. Alternatively, a plain `A` record works if players don't mind adding `:25565`.
3. If your public IP isn't static, use a dynamic DNS provider (e.g. DuckDNS, No-IP) and point your domain at the dynamic DNS hostname via a `CNAME`, or run a small updater that refreshes your DNS record when your IP changes.

## Performance

This runs on a home PC and home upload bandwidth rather than a data center, so the defaults are tuned down from vanilla:

- `VIEW_DISTANCE` (`8`) and `SIMULATION_DISTANCE` (`6`) are lower than vanilla's defaults of `10`. Simulation distance in particular drives CPU usage (mob AI, redstone, block ticks), so lowering it first is usually the biggest win if the server lags with several players on.
- `CONTAINER_MEMORY_LIMIT` (`5G`) caps the container to slightly more than `SERVER_MEMORY` (`4G`). The gap is headroom for the JVM's off-heap usage (metaspace, thread stacks, native buffers) on top of its heap. If you raise `SERVER_MEMORY`, raise `CONTAINER_MEMORY_LIMIT` by at least 1G as well, otherwise the container can get OOM-killed under load.

Note that the "name" a player sees in their multiplayer server list is whatever they typed in when adding your server — that's stored client-side and the server has no control over it. What the server does control is `MOTD` (the description line under that name) and `SERVER_ICON` (the 64x64 icon), both above.

Every service also caps its logs at 10MB × 3 files, so a long-running server doesn't slowly fill your disk with log history. This isn't configurable via `.env` — edit the `x-logging` block at the top of `docker-compose.yml` directly if you want different limits.

## Security

- `ONLINE_MODE` is pinned to `true` and must stay that way. It forces every player to authenticate with Mojang/Microsoft. Turning it off lets anyone connect under any username, including one in your `OPS` list, handing them full admin.
- `ENABLE_COMMAND_BLOCK` is pinned to `false`. Command blocks can run arbitrary server commands, so leave them off unless a trusted OP specifically needs them for redstone/minigame builds.
- Keep `RCON_PASSWORD` out of source control (already covered by `.gitignore`) and use a long random value, since RCON grants full console access to anyone who has it.
- Only add trusted usernames to `OPS`. An operator can change game rules, teleport, and access command blocks.
- `ENABLE_WHITELIST` is left `false` intentionally — this server is open to anyone who has the join address, not just a specific invite list. If that ever needs to change, set `ENABLE_WHITELIST=true` and list allowed usernames in `WHITELIST` (comma-separated); there's no wildcard value that means "allow all" within the whitelist itself, leaving it disabled is what achieves that.

## Gameplay Rules

Gamerules live in the world save, not `server.properties`, so this image has no direct env var for them. Instead, `docker-compose.yml` runs them as RCON commands every time the container starts, via [`RCON_CMDS_STARTUP`](https://github.com/itzg/docker-minecraft-server/blob/master/docs/configuration/auto-rcon-commands.md), driven by the `KEEP_INVENTORY`, `MOB_GRIEFING`, `FIRE_SPREAD_RADIUS`, and `DAYLIGHT_CYCLE` variables in `.env` (see the table above). Defaults match vanilla, so leaving them unset changes nothing.

This server version uses namespaced, snake_case gamerule IDs (e.g. `minecraft:keep_inventory`) rather than the older camelCase names (`keepInventory`) you'll see in a lot of tutorials — the old names are rejected with "Incorrect argument for command". All four commands below were verified against a real running container, not just documentation.

To change one, edit `.env` and recreate the container:

```
docker compose up -d
```

This re-applies the current `.env` values on top of your existing world — it does not reset or regenerate anything.

For a gamerule not covered by those four variables, set it directly (use tab-completion in-game after `/gamerule ` to see the exact current ID, since these have changed before and may change again):

```
docker exec minecraft-server rcon-cli gamerule <name> <value>
```

Rules set this way persist in the world save, but will be overwritten back to your `.env` value (or vanilla default) the next time the container restarts if that rule is one of the four managed above.

## Backups

The `backup` service automatically archives `./data` into `./backups` on the interval set by `BACKUP_INTERVAL`, pruning anything older than `BACKUP_RETENTION_DAYS`.

To trigger a manual save before an update or shutdown (`flush` forces it to disk immediately rather than queuing it — the same flag the `backup` service itself uses):

```
docker exec minecraft-server rcon-cli save-all flush
```

## Updating

```
docker compose pull
docker compose up -d
```

## Stopping

```
docker compose down
```

If you're running the `playit` profile, plain `docker compose down` will **not** stop it — profiles aren't remembered between commands, so it only targets `minecraft` and `backup`, leaving `minecraft-playit` running in the background. To stop everything:

```
docker compose --profile playit down
```

World data in `./data` is preserved across restarts and updates since it lives on the host, not inside the container.
