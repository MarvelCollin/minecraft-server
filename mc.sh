#!/usr/bin/env bash
set -uo pipefail

cd "$(dirname "$0")"

BOLD='\033[1m'
CYAN='\033[36m'
GREEN='\033[32m'
YELLOW='\033[33m'
RED='\033[31m'
DIM='\033[2m'
RESET='\033[0m'

ENV_FILE=".env"
CONTAINER="minecraft-server"
BACKUP_CONTAINER="minecraft-backup"

has_playit() {
  [ -f "$ENV_FILE" ] && grep -q 'PLAYIT_SECRET_KEY=.' "$ENV_FILE" 2>/dev/null
}

compose_cmd() {
  if has_playit; then
    docker compose --profile playit "$@"
  else
    docker compose "$@"
  fi
}

require_docker() {
  if ! command -v docker &>/dev/null; then
    echo -e "  ${RED}Docker not found. Install from https://docs.docker.com/get-docker/${RESET}"
    exit 1
  fi
  if ! docker info &>/dev/null; then
    echo -e "  ${RED}Docker not running. Start Docker Desktop or the Docker daemon.${RESET}"
    exit 1
  fi
}

require_env() {
  if [ ! -f "$ENV_FILE" ]; then
    echo -e "  ${RED}.env not found. Run: ./mc.sh setup${RESET}"
    exit 1
  fi
}

require_running() {
  if ! docker ps --format '{{.Names}}' 2>/dev/null | grep -q "^${CONTAINER}$"; then
    echo -e "  ${RED}Server not running. Run: ./mc.sh start${RESET}"
    exit 1
  fi
}

rcon() {
  docker exec "$CONTAINER" rcon-cli "$@" 2>/dev/null
}

env_get() {
  if [ -f "$ENV_FILE" ]; then
    sed -n "s/^$1=//p" "$ENV_FILE"
  fi
}

env_set() {
  local key="$1" val="$2"
  if grep -q "^${key}=" "$ENV_FILE" 2>/dev/null; then
    local tmpfile="${ENV_FILE}.tmp"
    while IFS= read -r line || [ -n "$line" ]; do
      if [[ "$line" == "${key}="* ]]; then
        echo "${key}=${val}"
      else
        echo "$line"
      fi
    done < "$ENV_FILE" > "$tmpfile"
    mv "$tmpfile" "$ENV_FILE"
  else
    echo "${key}=${val}" >> "$ENV_FILE"
  fi
}

cmd_setup() {
  echo ""
  echo -e "  ${CYAN}${BOLD}Server Setup${RESET}"
  echo ""

  require_docker
  echo -e "  ${GREEN}✓${RESET} Docker found"

  if ! docker compose version &>/dev/null; then
    echo -e "  ${RED}Docker Compose not found. Install Docker Compose v2.${RESET}"
    exit 1
  fi
  echo -e "  ${GREEN}✓${RESET} Docker Compose found"
  echo ""

  if [ -f "$ENV_FILE" ]; then
    echo -e "  ${YELLOW}.env already exists.${RESET}"
    echo -ne "  ${BOLD}Reconfigure?${RESET} [y/N]: "
    confirm=""
    read -r confirm
    if [[ ! "${confirm:-N}" =~ ^[Yy]$ ]]; then
      echo -e "  ${DIM}Keeping existing config${RESET}"
      echo ""
      return
    fi
  else
    cp .env.example "$ENV_FILE"
    PASSWORD=$(openssl rand -hex 16 2>/dev/null || head -c32 /dev/urandom | od -An -tx1 | tr -d ' \n')
    sed -i "s/RCON_PASSWORD=changeme/RCON_PASSWORD=${PASSWORD}/" "$ENV_FILE"
    echo -e "  ${GREEN}✓${RESET} Created .env with random RCON password"
  fi

  echo ""
  echo -e "  ${BOLD}Configure your server${RESET} ${DIM}(press Enter to keep current value)${RESET}"
  echo ""

  current=$(env_get SERVER_TYPE)
  echo -e "  ${BOLD}Server type${RESET} ${DIM}[${current:-VANILLA}]${RESET}"
  echo -e "    1) VANILLA  2) PAPER  3) FABRIC  4) FORGE"
  echo -ne "  ${CYAN}>${RESET} "
  choice=""
  read -r choice
  case "${choice:-}" in
    1) env_set SERVER_TYPE VANILLA ;;
    2) env_set SERVER_TYPE PAPER ;;
    3) env_set SERVER_TYPE FABRIC ;;
    4) env_set SERVER_TYPE FORGE ;;
    "") ;;
    *) env_set SERVER_TYPE "$choice" ;;
  esac

  current=$(env_get SERVER_VERSION)
  echo -ne "  ${BOLD}Minecraft version${RESET} ${DIM}[${current:-LATEST}]${RESET}: "
  val=""
  read -r val
  [ -n "${val:-}" ] && env_set SERVER_VERSION "$val"

  current=$(env_get GAME_MODE)
  echo -e "  ${BOLD}Game mode${RESET} ${DIM}[${current:-survival}]${RESET}"
  echo -e "    1) survival  2) creative  3) adventure  4) spectator"
  echo -ne "  ${CYAN}>${RESET} "
  choice=""
  read -r choice
  case "${choice:-}" in
    1) env_set GAME_MODE survival ;;
    2) env_set GAME_MODE creative ;;
    3) env_set GAME_MODE adventure ;;
    4) env_set GAME_MODE spectator ;;
    "") ;;
  esac

  current=$(env_get DIFFICULTY)
  echo -e "  ${BOLD}Difficulty${RESET} ${DIM}[${current:-normal}]${RESET}"
  echo -e "    1) peaceful  2) easy  3) normal  4) hard"
  echo -ne "  ${CYAN}>${RESET} "
  choice=""
  read -r choice
  case "${choice:-}" in
    1) env_set DIFFICULTY peaceful ;;
    2) env_set DIFFICULTY easy ;;
    3) env_set DIFFICULTY normal ;;
    4) env_set DIFFICULTY hard ;;
    "") ;;
  esac

  current=$(env_get MAX_PLAYERS)
  echo -ne "  ${BOLD}Max players${RESET} ${DIM}[${current:-20}]${RESET}: "
  val=""
  read -r val
  [ -n "${val:-}" ] && env_set MAX_PLAYERS "$val"

  current=$(env_get MOTD)
  echo -ne "  ${BOLD}Server description (MOTD)${RESET} ${DIM}[${current:-A Minecraft Server}]${RESET}: "
  val=""
  read -r val
  [ -n "${val:-}" ] && env_set MOTD "$val"

  current=$(env_get KEEP_INVENTORY)
  echo -ne "  ${BOLD}Keep inventory on death?${RESET} ${DIM}[${current:-false}]${RESET} [y/N]: "
  val=""
  read -r val
  case "${val:-}" in
    [Yy]*) env_set KEEP_INVENTORY true ;;
    [Nn]*) env_set KEEP_INVENTORY false ;;
  esac

  current=$(env_get OPS)
  echo -ne "  ${BOLD}Operators${RESET} ${DIM}(comma-separated) [${current:-none}]${RESET}: "
  val=""
  read -r val
  [ -n "${val:-}" ] && env_set OPS "$val"

  echo ""
  echo -e "  ${GREEN}${BOLD}Setup complete!${RESET}"
  echo ""
  echo -ne "  ${BOLD}Start server now?${RESET} [Y/n]: "
  val=""
  read -r val
  if [[ "${val:-Y}" =~ ^[Yy]?$ ]]; then
    cmd_start
  fi
}

cmd_start() {
  require_docker
  require_env
  echo ""

  if docker ps --format '{{.Names}}' 2>/dev/null | grep -q "^${CONTAINER}$"; then
    echo -e "  ${YELLOW}Server is already running.${RESET}"
    echo -ne "  ${BOLD}Restart instead?${RESET} [y/N]: "
    confirm=""
    read -r confirm
    if [[ "${confirm:-N}" =~ ^[Yy]$ ]]; then
      cmd_restart
      return
    fi
    return
  fi

  echo -e "  ${BOLD}Starting server...${RESET}"
  compose_cmd up -d
  echo ""
  echo -e "  ${GREEN}✓ Server started${RESET}"
  if has_playit; then
    echo -e "  ${DIM}playit.gg tunnel enabled${RESET}"
  fi
  echo -e "  ${DIM}Watch logs: ./mc.sh logs${RESET}"
  echo ""
}

cmd_stop() {
  require_docker
  echo ""

  if ! docker ps --format '{{.Names}}' 2>/dev/null | grep -q "^${CONTAINER}$"; then
    echo -e "  ${DIM}Server is already stopped.${RESET}"
    echo ""
    return
  fi

  echo -e "  ${BOLD}Stopping server...${RESET}"
  rcon save-all flush 2>/dev/null || true
  sleep 1
  compose_cmd down
  echo -e "  ${GREEN}✓ Server stopped${RESET}"
  echo ""
}

cmd_restart() {
  require_docker
  require_env
  echo ""
  echo -e "  ${BOLD}Restarting server...${RESET}"

  if docker ps --format '{{.Names}}' 2>/dev/null | grep -q "^${CONTAINER}$"; then
    rcon save-all flush 2>/dev/null || true
    sleep 1
  fi

  compose_cmd restart
  echo -e "  ${GREEN}✓ Server restarted${RESET}"
  echo ""
}

cmd_status() {
  require_docker
  echo ""
  echo -e "  ${CYAN}${BOLD}Server Status${RESET}"
  echo ""

  if ! docker ps --format '{{.Names}}' 2>/dev/null | grep -q "^${CONTAINER}$"; then
    echo -e "  ${RED}●${RESET} Server is ${RED}${BOLD}offline${RESET}"
    echo ""
    return
  fi

  echo -e "  ${GREEN}●${RESET} Server is ${GREEN}${BOLD}online${RESET}"

  uptime_raw=$(docker inspect --format '{{.State.StartedAt}}' "$CONTAINER" 2>/dev/null)
  if [ -n "${uptime_raw:-}" ]; then
    start_epoch=$(date -d "$uptime_raw" +%s 2>/dev/null || echo "")
    if [ -n "${start_epoch:-}" ]; then
      now_epoch=$(date +%s)
      diff=$((now_epoch - start_epoch))
      days=$((diff / 86400))
      hours=$(( (diff % 86400) / 3600 ))
      mins=$(( (diff % 3600) / 60 ))
      if [ $days -gt 0 ]; then
        echo -e "  ${BOLD}Uptime:${RESET}  ${days}d ${hours}h ${mins}m"
      elif [ $hours -gt 0 ]; then
        echo -e "  ${BOLD}Uptime:${RESET}  ${hours}h ${mins}m"
      else
        echo -e "  ${BOLD}Uptime:${RESET}  ${mins}m"
      fi
    fi
  fi

  health=$(docker inspect --format '{{.State.Health.Status}}' "$CONTAINER" 2>/dev/null || echo "unknown")
  case "$health" in
    healthy)   echo -e "  ${BOLD}Health:${RESET}  ${GREEN}healthy${RESET}" ;;
    unhealthy) echo -e "  ${BOLD}Health:${RESET}  ${RED}unhealthy${RESET}" ;;
    starting)  echo -e "  ${BOLD}Health:${RESET}  ${YELLOW}starting${RESET}" ;;
    *)         echo -e "  ${BOLD}Health:${RESET}  ${DIM}$health${RESET}" ;;
  esac

  players=$(rcon list 2>/dev/null)
  if [ -n "${players:-}" ]; then
    echo -e "  ${BOLD}Players:${RESET} $players"
  fi

  server_type=$(env_get SERVER_TYPE)
  version=$(env_get SERVER_VERSION)
  port=$(env_get SERVER_PORT)
  echo -e "  ${BOLD}Type:${RESET}    ${server_type:-VANILLA}"
  echo -e "  ${BOLD}Version:${RESET} ${version:-LATEST}"
  echo -e "  ${BOLD}Port:${RESET}    ${port:-25565}"
  echo ""

  if docker ps --format '{{.Names}}' 2>/dev/null | grep -q "^${BACKUP_CONTAINER}$"; then
    echo -e "  ${GREEN}●${RESET} Backup service running"
  else
    echo -e "  ${RED}●${RESET} Backup service stopped"
  fi

  if docker ps --format '{{.Names}}' 2>/dev/null | grep -q "^minecraft-playit$"; then
    echo -e "  ${GREEN}●${RESET} playit.gg tunnel active"
  fi
  echo ""
}

cmd_logs() {
  require_docker
  docker compose logs -f minecraft
}

cmd_console() {
  require_docker
  require_running
  echo ""
  echo -e "  ${CYAN}${BOLD}Server Console${RESET} ${DIM}(type 'exit' or Ctrl+C to leave)${RESET}"
  echo ""
  docker exec -it "$CONTAINER" rcon-cli
}

cmd_mods() {
  if [ -f "./mods.sh" ]; then
    bash ./mods.sh "$@"
  else
    echo -e "  ${RED}mods.sh not found${RESET}"
  fi
}

cmd_backup() {
  require_docker
  require_running
  echo ""
  echo -e "  ${BOLD}Triggering manual backup...${RESET}"
  rcon save-all flush
  sleep 2

  if docker ps --format '{{.Names}}' 2>/dev/null | grep -q "^${BACKUP_CONTAINER}$"; then
    docker exec "$BACKUP_CONTAINER" backup now 2>/dev/null && \
      echo -e "  ${GREEN}✓ Backup triggered${RESET}" || \
      echo -e "  ${YELLOW}Save flushed to disk. Next scheduled backup will pick it up.${RESET}"
  else
    echo -e "  ${YELLOW}Backup container not running. Save flushed to disk.${RESET}"
  fi
  echo ""
}

cmd_backup_list() {
  echo ""
  echo -e "  ${CYAN}${BOLD}Backups${RESET}"
  echo ""
  if [ ! -d "backups" ] || [ -z "$(ls -A backups/ 2>/dev/null)" ]; then
    echo -e "  ${DIM}No backups found.${RESET}"
    echo ""
    return
  fi
  BACKUP_FILES=()
  for f in backups/*; do
    BACKUP_FILES+=("$f")
    local idx=${#BACKUP_FILES[@]}
    size=$(du -h "$f" 2>/dev/null | cut -f1)
    mod_date=$(date -r "$f" "+%Y-%m-%d %H:%M" 2>/dev/null || stat --format="%y" "$f" 2>/dev/null | cut -d. -f1)
    echo -e "  ${BOLD}${idx})${RESET} $(basename "$f")  ${DIM}${size}  ${mod_date}${RESET}"
  done
  echo ""
}

cmd_backup_restore() {
  local target="${1:-}"

  if [ -z "$target" ]; then
    echo -e "  ${RED}Specify a backup file. Run: ./mc.sh backup list${RESET}"
    return
  fi

  local backup_path=""
  if [ -f "backups/$target" ]; then
    backup_path="backups/$target"
  elif [ -f "$target" ]; then
    backup_path="$target"
  else
    echo -e "  ${RED}Backup not found: $target${RESET}"
    echo -e "  ${DIM}Run: ./mc.sh backup list${RESET}"
    return
  fi

  echo ""
  echo -e "  ${YELLOW}${BOLD}This will replace current world data with: $(basename "$backup_path")${RESET}"
  echo -ne "  ${BOLD}Continue?${RESET} [y/N]: "
  confirm=""
  read -r confirm
  if [[ ! "${confirm:-N}" =~ ^[Yy]$ ]]; then
    echo -e "  ${DIM}Cancelled${RESET}"
    return
  fi

  if docker ps --format '{{.Names}}' 2>/dev/null | grep -q "^${CONTAINER}$"; then
    echo -e "  ${BOLD}Stopping server...${RESET}"
    compose_cmd down
  fi

  echo -e "  ${BOLD}Restoring...${RESET}"
  if [[ "$backup_path" == *.tar.gz ]] || [[ "$backup_path" == *.tgz ]]; then
    rm -rf data/world data/world_nether data/world_the_end 2>/dev/null
    tar -xzf "$backup_path" -C data/
  elif [[ "$backup_path" == *.zip ]]; then
    rm -rf data/world data/world_nether data/world_the_end 2>/dev/null
    unzip -o "$backup_path" -d data/
  else
    echo -e "  ${RED}Unknown backup format. Expected .tar.gz or .zip${RESET}"
    return
  fi

  echo -e "  ${GREEN}✓ Backup restored${RESET}"
  echo ""
  echo -ne "  ${BOLD}Start server now?${RESET} [Y/n]: "
  confirm=""
  read -r confirm
  if [[ "${confirm:-Y}" =~ ^[Yy]?$ ]]; then
    cmd_start
  fi
}

cmd_update() {
  require_docker
  require_env
  echo ""
  echo -e "  ${BOLD}Updating server images...${RESET}"

  if docker ps --format '{{.Names}}' 2>/dev/null | grep -q "^${CONTAINER}$"; then
    rcon save-all flush 2>/dev/null || true
    sleep 1
  fi

  compose_cmd pull
  compose_cmd up -d
  echo ""
  echo -e "  ${GREEN}✓ Updated and restarted${RESET}"
  echo ""
}

cmd_players() {
  require_docker
  require_running
  echo ""
  result=$(rcon list 2>/dev/null)
  if [ -n "${result:-}" ]; then
    echo -e "  ${BOLD}$result${RESET}"
  else
    echo -e "  ${RED}Could not query players${RESET}"
  fi
  echo ""
}

cmd_op() {
  local action="${1:-add}"
  local name="${2:-}"

  if [ -z "$name" ]; then
    echo -ne "  ${BOLD}Username:${RESET} "
    read -r name
    [ -z "${name:-}" ] && return
  fi

  require_docker
  require_running

  case "$action" in
    add)
      rcon op "$name"
      echo -e "  ${GREEN}✓ $name is now an operator${RESET}"
      ;;
    remove)
      rcon deop "$name"
      echo -e "  ${GREEN}✓ $name removed as operator${RESET}"
      ;;
  esac
}

cmd_say() {
  local msg="${*}"
  if [ -z "$msg" ]; then
    echo -ne "  ${BOLD}Message:${RESET} "
    read -r msg
    [ -z "${msg:-}" ] && return
  fi
  require_docker
  require_running
  rcon say "$msg"
  echo -e "  ${GREEN}✓ Broadcast sent${RESET}"
}

cmd_kick() {
  local name="${1:-}"
  if [ -z "$name" ]; then
    echo -ne "  ${BOLD}Username:${RESET} "
    read -r name
    [ -z "${name:-}" ] && return
  fi
  local reason="${2:-Kicked by server admin}"
  require_docker
  require_running
  rcon kick "$name" "$reason"
  echo -e "  ${GREEN}✓ $name kicked${RESET}"
}

cmd_ban() {
  local action="${1:-add}"
  local name="${2:-}"
  if [ -z "$name" ]; then
    echo -ne "  ${BOLD}Username:${RESET} "
    read -r name
    [ -z "${name:-}" ] && return
  fi
  require_docker
  require_running
  case "$action" in
    add)
      rcon ban "$name"
      echo -e "  ${GREEN}✓ $name banned${RESET}"
      ;;
    remove)
      rcon pardon "$name"
      echo -e "  ${GREEN}✓ $name unbanned${RESET}"
      ;;
    list)
      result=$(rcon banlist 2>/dev/null)
      echo -e "  ${BOLD}${result:-No bans}${RESET}"
      ;;
  esac
}

cmd_whitelist() {
  local action="${1:-list}"
  local name="${2:-}"

  require_docker
  require_running

  case "$action" in
    add)
      if [ -z "$name" ]; then
        echo -ne "  ${BOLD}Username:${RESET} "
        read -r name
        [ -z "${name:-}" ] && return
      fi
      rcon whitelist add "$name"
      echo -e "  ${GREEN}✓ $name added to whitelist${RESET}"
      ;;
    remove)
      if [ -z "$name" ]; then
        echo -ne "  ${BOLD}Username:${RESET} "
        read -r name
        [ -z "${name:-}" ] && return
      fi
      rcon whitelist remove "$name"
      echo -e "  ${GREEN}✓ $name removed from whitelist${RESET}"
      ;;
    on)
      rcon whitelist on
      echo -e "  ${GREEN}✓ Whitelist enabled${RESET}"
      ;;
    off)
      rcon whitelist off
      echo -e "  ${GREEN}✓ Whitelist disabled${RESET}"
      ;;
    list)
      result=$(rcon whitelist list 2>/dev/null)
      echo -e "  ${BOLD}${result:-Whitelist is empty}${RESET}"
      ;;
  esac
}

menu() {
  echo ""
  echo -e "  ${CYAN}${BOLD}╔════════════════════════════════════════╗${RESET}"
  echo -e "  ${CYAN}${BOLD}║      Minecraft Server Manager         ║${RESET}"
  echo -e "  ${CYAN}${BOLD}╚════════════════════════════════════════╝${RESET}"
  echo ""

  if [ ! -f "$ENV_FILE" ]; then
    echo -e "  ${YELLOW}First time? Running setup...${RESET}"
    echo ""
    cmd_setup
  fi

  while true; do
    if docker ps --format '{{.Names}}' 2>/dev/null | grep -q "^${CONTAINER}$"; then
      player_info=$(rcon list 2>/dev/null | head -1)
      if [ -n "${player_info:-}" ]; then
        echo -e "  ${GREEN}●${RESET} Server ${GREEN}online${RESET}  ${DIM}— ${player_info}${RESET}"
      else
        echo -e "  ${GREEN}●${RESET} Server ${GREEN}online${RESET}"
      fi
    else
      echo -e "  ${RED}●${RESET} Server ${RED}offline${RESET}"
    fi
    echo ""
    echo -e "  ${BOLD} 1)${RESET} Start server"
    echo -e "  ${BOLD} 2)${RESET} Stop server"
    echo -e "  ${BOLD} 3)${RESET} Restart server"
    echo -e "  ${BOLD} 4)${RESET} Server status"
    echo -e "  ${BOLD} 5)${RESET} View logs"
    echo -e "  ${BOLD} 6)${RESET} Server console"
    echo -e "  ${BOLD} 7)${RESET} Manage mods"
    echo -e "  ${BOLD} 8)${RESET} Manage backups"
    echo -e "  ${BOLD} 9)${RESET} Manage players"
    echo -e "  ${BOLD}10)${RESET} Update server"
    echo -e "  ${BOLD}11)${RESET} Setup / reconfigure"
    echo -e "  ${BOLD} 0)${RESET} Exit"
    echo ""
    echo -ne "  ${CYAN}${BOLD}>${RESET} "
    choice=""
    read -r choice
    echo ""

    case "${choice:-}" in
      1) cmd_start ;;
      2) cmd_stop ;;
      3) cmd_restart ;;
      4) cmd_status ;;
      5) cmd_logs ;;
      6) cmd_console ;;
      7) cmd_mods ;;
      8)
        echo -e "  ${BOLD}1)${RESET} Trigger backup now"
        echo -e "  ${BOLD}2)${RESET} List backups"
        echo -e "  ${BOLD}3)${RESET} Restore backup"
        echo -ne "  ${CYAN}>${RESET} "
        sub=""
        read -r sub
        case "${sub:-}" in
          1) cmd_backup ;;
          2) cmd_backup_list ;;
          3)
            cmd_backup_list
            if [ ${#BACKUP_FILES[@]} -gt 0 ]; then
              echo -ne "  ${BOLD}Restore which?${RESET} [1-${#BACKUP_FILES[@]}, 0 to cancel]: "
              bnum=""
              read -r bnum
              if [ "${bnum:-0}" != "0" ] && [[ "${bnum:-}" =~ ^[0-9]+$ ]] && [ "$bnum" -ge 1 ] && [ "$bnum" -le "${#BACKUP_FILES[@]}" ]; then
                cmd_backup_restore "${BACKUP_FILES[$((bnum-1))]}"
              fi
            fi
            ;;
        esac
        ;;
      9)
        echo -e "  ${BOLD} 1)${RESET} List online players"
        echo -e "  ${BOLD} 2)${RESET} Broadcast message"
        echo -e "  ${BOLD} 3)${RESET} Kick player"
        echo -e "  ${BOLD} 4)${RESET} Ban player"
        echo -e "  ${BOLD} 5)${RESET} Unban player"
        echo -e "  ${BOLD} 6)${RESET} Add operator"
        echo -e "  ${BOLD} 7)${RESET} Remove operator"
        echo -e "  ${BOLD} 8)${RESET} Add to whitelist"
        echo -e "  ${BOLD} 9)${RESET} Remove from whitelist"
        echo -e "  ${BOLD}10)${RESET} Toggle whitelist on/off"
        echo -e "  ${BOLD}11)${RESET} Show whitelist"
        echo -ne "  ${CYAN}>${RESET} "
        sub=""
        read -r sub
        case "${sub:-}" in
          1) cmd_players ;;
          2) cmd_say ;;
          3) cmd_kick ;;
          4) cmd_ban add ;;
          5) cmd_ban remove ;;
          6) cmd_op add ;;
          7) cmd_op remove ;;
          8) cmd_whitelist add ;;
          9) cmd_whitelist remove ;;
          10)
            echo -ne "  ${BOLD}Enable or disable?${RESET} [on/off]: "
            toggle=""
            read -r toggle
            cmd_whitelist "${toggle:-on}"
            ;;
          11) cmd_whitelist list ;;
        esac
        ;;
      10) cmd_update ;;
      11) cmd_setup ;;
      0)
        echo ""
        exit 0
        ;;
      *) echo -e "  ${RED}Invalid option${RESET}" ;;
    esac

    echo ""
    echo -e "  ${DIM}────────────────────────────────────────${RESET}"
    echo ""
  done
}

case "${1:-}" in
  setup)     cmd_setup ;;
  start)     cmd_start ;;
  stop)      cmd_stop ;;
  restart)   cmd_restart ;;
  status)    cmd_status ;;
  logs)      cmd_logs ;;
  console)   cmd_console ;;
  mods)      shift; cmd_mods "$@" ;;
  backup)
    case "${2:-}" in
      list)    cmd_backup_list ;;
      restore) cmd_backup_restore "${3:-}" ;;
      *)       cmd_backup ;;
    esac
    ;;
  update)    cmd_update ;;
  players)   cmd_players ;;
  say)       shift; cmd_say "$*" ;;
  kick)      cmd_kick "${2:-}" "${3:-}" ;;
  ban)       cmd_ban add "${2:-}" ;;
  unban)     cmd_ban remove "${2:-}" ;;
  banlist)   cmd_ban list "" ;;
  op)        cmd_op add "${2:-}" ;;
  deop)      cmd_op remove "${2:-}" ;;
  whitelist) cmd_whitelist "${2:-list}" "${3:-}" ;;
  help|-h|--help)
    echo ""
    echo -e "  ${BOLD}Usage:${RESET} ./mc.sh [command]"
    echo ""
    echo -e "  ${BOLD}Commands:${RESET}"
    echo "    setup              Setup or reconfigure server"
    echo "    start              Start server"
    echo "    stop               Stop server"
    echo "    restart            Restart server"
    echo "    status             Show server status and player count"
    echo "    logs               Follow server logs"
    echo "    console            Open RCON console"
    echo "    mods               Manage mods (interactive)"
    echo "    backup             Trigger manual backup"
    echo "    backup list        List available backups"
    echo "    backup restore <f> Restore from backup file"
    echo "    update             Pull latest images and restart"
    echo "    players            List online players"
    echo "    say <msg>          Broadcast message to all players"
    echo "    kick <name>        Kick a player"
    echo "    ban <name>         Ban a player"
    echo "    unban <name>       Unban a player"
    echo "    banlist            Show banned players"
    echo "    op <name>          Make player an operator"
    echo "    deop <name>        Remove operator status"
    echo "    whitelist add <n>  Add player to whitelist"
    echo "    whitelist remove   Remove from whitelist"
    echo "    whitelist list     Show whitelist"
    echo "    whitelist on|off   Toggle whitelist"
    echo ""
    echo -e "  ${DIM}Run without arguments for interactive menu.${RESET}"
    echo ""
    ;;
  "")        menu ;;
  *)
    echo -e "  ${RED}Unknown command: $1${RESET}"
    echo -e "  ${DIM}Run: ./mc.sh help${RESET}"
    exit 1
    ;;
esac
