# minecraft-server
![License](https://img.shields.io/github/license/MarvelCollin/minecraft-server) ![Last commit](https://img.shields.io/github/last-commit/MarvelCollin/minecraft-server) ![Docker](https://img.shields.io/badge/docker-ready-2496ED?logo=docker&logoColor=white)

A self-hosted, Dockerized Minecraft server with automated backups, ready to be exposed to the public internet.

## Quick Start

```
./mc.sh setup    # checks Docker, creates .env, walks you through config
./mc.sh start    # starts the server
./mc.sh logs     # watch until it says "Done"
```

Run `./mc.sh` with no arguments for an interactive menu.

## Commands

```
./mc.sh setup        # interactive setup wizard
./mc.sh start        # start server (auto-detects playit.gg)
./mc.sh stop         # graceful save + stop
./mc.sh restart      # restart
./mc.sh status       # uptime, health, players, version
./mc.sh logs         # follow server logs
./mc.sh console      # RCON console
./mc.sh mods         # mod manager
./mc.sh backup       # trigger manual backup
./mc.sh backup list  # list backups
./mc.sh backup restore <file>
./mc.sh update       # pull latest images + restart
./mc.sh players      # list online players
./mc.sh say <msg>    # broadcast message
./mc.sh kick <name>  # kick player
./mc.sh ban <name>   # ban player
./mc.sh unban <name> # unban player
./mc.sh op <name>    # grant operator
./mc.sh deop <name>  # revoke operator
./mc.sh whitelist add|remove|list|on|off
```

## Configuration

All settings live in `.env` (created by `./mc.sh setup`). Common ones:

| Variable | Default | Description |
|---|---|---|
| `SERVER_TYPE` | `VANILLA` | `VANILLA`, `PAPER`, `FABRIC`, `FORGE`, ... |
| `SERVER_VERSION` | `LATEST` | Minecraft version |
| `SERVER_MEMORY` | `4G` | JVM heap size |
| `DIFFICULTY` | `normal` | `peaceful`, `easy`, `normal`, `hard` |
| `GAME_MODE` | `survival` | `survival`, `creative`, `adventure`, `spectator` |
| `MAX_PLAYERS` | `20` | Max concurrent players |
| `MOTD` | `A Minecraft Server` | Description in multiplayer list |
| `KEEP_INVENTORY` | `false` | Keep items on death |
| `OPS` | (empty) | Comma-separated operator usernames |
| `ENABLE_WHITELIST` | `false` | Restrict access to whitelist |
| `BACKUP_INTERVAL` | `6h` | Auto-backup frequency |
| `PLAYIT_SECRET_KEY` | (empty) | playit.gg tunnel key (see below) |

After editing `.env`, run `./mc.sh restart` to apply.

Full variable reference: https://docker-minecraft-server.readthedocs.io/en/latest/variables/

## Mods

```
./mc.sh mods
```

Set `SERVER_TYPE` to `FABRIC` or `FORGE` first (vanilla can't load mods). The mod manager accepts Modrinth slugs (`sodium`), download URLs, or local `.jar` files dropped in `mods/`.

CLI shortcut: `./mods.sh add sodium lithium https://example.com/mod.jar`

## Exposing the Server

### Option A: playit.gg (easiest, works behind CGNAT)

1. Sign up at [playit.gg](https://playit.gg/) and create a Docker agent.
2. Copy the `SECRET_KEY` into `.env`:
   ```
   PLAYIT_SECRET_KEY=<your key>
   ```
3. `./mc.sh start` — it auto-detects the key and starts the tunnel.
4. In the playit dashboard, create a **Minecraft Java** tunnel with Local IP `minecraft` and port `25565`.
5. Share the assigned `something.joinmc.link` address with players.

### Option B: port forwarding (needs a real public IP)

1. Set a static local IP on your router (DHCP reservation).
2. Port forward `25565/tcp` to that IP.
3. Share `your-public-ip:25565` with players.

Optional: add a `SRV` record for `_minecraft._tcp` on your domain so players can join without the port number.

## Security

- `ONLINE_MODE` is pinned to `true` — every player must authenticate with Mojang/Microsoft.
- `ENABLE_COMMAND_BLOCK` is pinned to `false`.
- `RCON_PASSWORD` is auto-generated and excluded from git. Don't commit it.
- Only add trusted usernames to `OPS`.

## Performance

Defaults are tuned for home hosting:

- `VIEW_DISTANCE=8` and `SIMULATION_DISTANCE=6` (vanilla defaults are `10`). Lower simulation distance first if lagging.
- `CONTAINER_MEMORY_LIMIT=5G` gives 1G headroom above `SERVER_MEMORY=4G` for JVM overhead. If you raise one, raise both.
- Logs capped at 10MB × 3 files per service.
