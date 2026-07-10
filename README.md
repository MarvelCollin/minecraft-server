# minecraft-server

A self-hosted, Dockerized Minecraft server with automated backups, ready to be exposed to the public internet.

## Requirements

- Docker
- Docker Compose

## Quick Start

1. Copy the environment template and edit it:

   ```
   cp .env.example .env
   ```

2. Set a strong `RCON_PASSWORD` in `.env`.

3. Start the server:

   ```
   docker compose up -d
   ```

4. Check the logs until the server reports "Done":

   ```
   docker compose logs -f minecraft
   ```

The world data is stored in `./data` and backups are stored in `./backups`, both on your host machine.

## Configuration

All settings are controlled through `.env`. See `.env.example` for the full list. Common ones:

| Variable | Description | Default |
|---|---|---|
| `SERVER_PORT` | Host port mapped to the server | `25565` |
| `SERVER_TYPE` | Server software (`VANILLA`, `PAPER`, `FABRIC`, `FORGE`, ...) | `VANILLA` |
| `SERVER_VERSION` | Minecraft version | `LATEST` |
| `SERVER_MEMORY` | Memory allocated to the JVM | `4G` |
| `DIFFICULTY` | `peaceful`, `easy`, `normal`, `hard` | `normal` |
| `GAME_MODE` | `survival`, `creative`, `adventure`, `spectator` | `survival` |
| `MAX_PLAYERS` | Maximum concurrent players | `20` |
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

## Security

- `ONLINE_MODE` is pinned to `true` and must stay that way. It forces every player to authenticate with Mojang/Microsoft. Turning it off lets anyone connect under any username, including one in your `OPS` list, handing them full admin.
- `ENABLE_COMMAND_BLOCK` is pinned to `false`. Command blocks can run arbitrary server commands, so leave them off unless a trusted OP specifically needs them for redstone/minigame builds.
- Keep `RCON_PASSWORD` out of source control (already covered by `.gitignore`) and use a long random value, since RCON grants full console access to anyone who has it.
- Only add trusted usernames to `OPS`. An operator can change game rules, teleport, and access command blocks.

## Gameplay Rules

Gamerules (like `keepInventory`) live in the world save, not in `.env`, so they're set once via RCON rather than as an environment variable. Useful ones for a casual public server:

```
docker exec minecraft-server rcon-cli gamerule keepInventory true
docker exec minecraft-server rcon-cli gamerule mobGriefing false
docker exec minecraft-server rcon-cli gamerule doDaylightCycle true
```

- `keepInventory true` — players keep their items on death instead of dropping them, which cuts down on rage-quits from griefers or PvP deaths on a public server.
- `mobGriefing false` — stops creepers, endermen, and other mobs from destroying blocks or picking them up.

These persist across restarts once set, so they only need to be run again if you start a fresh world.

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
