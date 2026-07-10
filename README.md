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
| `RCON_PASSWORD` | Password for remote console access | (required) |
| `BACKUP_INTERVAL` | How often the backup service runs | `6h` |
| `BACKUP_RETENTION_DAYS` | How long backups are kept | `7` |

Full list of supported variables: https://docker-minecraft-server.readthedocs.io/en/latest/variables/

## Exposing the Server Publicly

To let anyone join over the internet, traffic on port `25565/tcp` needs to reach the machine running Docker.

1. **Give your PC a static local IP** on your router (DHCP reservation), so port forwarding keeps working after reboots.
2. **Port forward** `25565/tcp` on your router to that local IP.
3. **Find your public IP** by searching "what is my ip" and share `your-public-ip:25565` with players to test.

If players still cannot connect, your ISP is likely using **CGNAT** (common on many residential/mobile plans), meaning you don't have a real public IP to forward to. In that case, use a tunnel service instead of port forwarding, such as:

- [Cloudflare Tunnel](https://developers.cloudflare.com/cloudflare-one/connections/connect-networks/)
- [playit.gg](https://playit.gg/)

## Using a Domain

Once port forwarding works, point a domain at your server instead of sharing a raw IP:

1. Buy a domain from any registrar.
2. Add a `SRV` record for `_minecraft._tcp` pointing to your host, so players can join with just `play.yourdomain.com` without a port. Alternatively, a plain `A` record works if players don't mind adding `:25565`.
3. If your public IP isn't static, use a dynamic DNS provider (e.g. DuckDNS, No-IP) and point your domain at the dynamic DNS hostname via a `CNAME`, or run a small updater that refreshes your DNS record when your IP changes.

## Performance

This runs on a home PC and home upload bandwidth rather than a data center, so the defaults are tuned down from vanilla:

- `VIEW_DISTANCE` (`8`) and `SIMULATION_DISTANCE` (`6`) are lower than vanilla's defaults of `10`. Simulation distance in particular drives CPU usage (mob AI, redstone, block ticks), so lowering it first is usually the biggest win if the server lags with several players on.
- `CONTAINER_MEMORY_LIMIT` (`5G`) caps the container to slightly more than `SERVER_MEMORY` (`4G`). The gap is headroom for the JVM's off-heap usage (metaspace, thread stacks, native buffers) on top of its heap. If you raise `SERVER_MEMORY`, raise `CONTAINER_MEMORY_LIMIT` by at least 1G as well, otherwise the container can get OOM-killed under load.

Note that the "name" a player sees in their multiplayer server list is whatever they typed in when adding your server — that's stored client-side and the server has no control over it. What the server does control is `MOTD` (the description line under that name) and `SERVER_ICON` (the 64x64 icon), both above.

## Security

- `ONLINE_MODE` is pinned to `true` and must stay that way. It forces every player to authenticate with Mojang/Microsoft. Turning it off lets anyone connect under any username, including one in your `OPS` list, handing them full admin.
- `ENABLE_COMMAND_BLOCK` is pinned to `false`. Command blocks can run arbitrary server commands, so leave them off unless a trusted OP specifically needs them for redstone/minigame builds.
- Keep `RCON_PASSWORD` out of source control (already covered by `.gitignore`) and use a long random value, since RCON grants full console access to anyone who has it.
- Only add trusted usernames to `OPS`. An operator can change game rules, teleport, and access command blocks.

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

To trigger a manual save before an update or shutdown:

```
docker exec minecraft-server rcon-cli save-all
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

World data in `./data` is preserved across restarts and updates since it lives on the host, not inside the container.
