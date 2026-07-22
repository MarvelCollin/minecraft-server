#!/usr/bin/env bash
set -uo pipefail

cd "$(dirname "$0")"

MODS_FILE="mods.txt"
ENV_FILE=".env"
MODS_DIR="mods"
DATA_MODS_DIR="data/mods"

BOLD='\033[1m'
CYAN='\033[36m'
GREEN='\033[32m'
YELLOW='\033[33m'
RED='\033[31m'
DIM='\033[2m'
RESET='\033[0m'

touch "$MODS_FILE"
mkdir -p "$MODS_DIR"

check_server_type() {
  if [ -f "$ENV_FILE" ]; then
    local stype
    stype=$(sed -n 's/^SERVER_TYPE=//p' "$ENV_FILE")
    if [ "${stype:-VANILLA}" = "VANILLA" ]; then
      echo -e "  ${YELLOW}${BOLD}Warning:${RESET} SERVER_TYPE is VANILLA. Mods require FABRIC, FORGE, or similar."
      echo -ne "  ${BOLD}Continue anyway?${RESET} [y/N]: "
      local confirm=""
      read -r confirm
      if [[ ! "${confirm:-N}" =~ ^[Yy]$ ]]; then
        echo -e "  ${DIM}Set SERVER_TYPE in .env first, then try again.${RESET}"
        exit 0
      fi
    fi
  fi
}

get_modrinth_projects() {
  if [ -f "$ENV_FILE" ]; then
    sed -n 's/^MODRINTH_PROJECTS=//p' "$ENV_FILE"
  fi
}

set_modrinth_projects() {
  if grep -q '^MODRINTH_PROJECTS=' "$ENV_FILE" 2>/dev/null; then
    sed -i "s/^MODRINTH_PROJECTS=.*/MODRINTH_PROJECTS=$1/" "$ENV_FILE"
  else
    echo "MODRINTH_PROJECTS=$1" >> "$ENV_FILE"
  fi
}

add_entry() {
  local entry="$1"
  if [[ "$entry" =~ ^https?:// ]]; then
    if grep -qxF "$entry" "$MODS_FILE" 2>/dev/null; then
      echo -e "    ${YELLOW}already exists${RESET}"
      return 1
    fi
    echo "$entry" >> "$MODS_FILE"
    echo -e "    ${GREEN}✓ added (url)${RESET}"
    return 0
  fi

  if [ ! -f "$ENV_FILE" ]; then
    echo -e "    ${RED}run ./server.sh setup first${RESET}"
    return 1
  fi
  local current
  current=$(get_modrinth_projects)
  if [ -n "${current:-}" ] && echo ",$current," | grep -q ",$entry,"; then
    echo -e "    ${YELLOW}$entry already exists${RESET}"
    return 1
  fi
  if [ -z "${current:-}" ]; then
    set_modrinth_projects "$entry"
  else
    set_modrinth_projects "$current,$entry"
  fi
  echo -e "    ${GREEN}✓ $entry (modrinth)${RESET}"
  return 0
}

do_add() {
  check_server_type
  echo ""

  shopt -s nullglob
  jars=("$MODS_DIR"/*.jar)
  shopt -u nullglob
  if [ ${#jars[@]} -gt 0 ]; then
    echo -e "  ${YELLOW}${BOLD}Found ${#jars[@]} .jar file(s) in mods/${RESET}"
    for jar in "${jars[@]}"; do
      echo -e "    $(basename "$jar")"
    done
    echo ""
    echo -ne "  ${BOLD}Install them?${RESET} [Y/n]: "
    confirm=""
    read -r confirm
    if [[ "${confirm:-Y}" =~ ^[Yy]?$ ]]; then
      mkdir -p "$DATA_MODS_DIR"
      for jar in "${jars[@]}"; do
        cp "$jar" "$DATA_MODS_DIR/"
        echo -e "    ${GREEN}✓ $(basename "$jar")${RESET}"
      done
    fi
    echo ""
  fi

  echo -e "  ${BOLD}Paste URLs or Modrinth slugs${RESET} ${DIM}(empty line to finish)${RESET}"
  count=0
  while true; do
    echo -ne "  ${CYAN}>${RESET} "
    entry=""
    read -r entry
    if [ -z "${entry:-}" ]; then
      break
    fi
    add_entry "$entry" && count=$((count + 1))
  done
  if [ $count -gt 0 ]; then
    echo ""
    echo -e "  ${GREEN}${BOLD}$count mod(s) added${RESET}"
    echo -e "  ${DIM}Restart to apply: ./server.sh restart${RESET}"
  fi
}

do_list() {
  echo ""
  echo -e "  ${CYAN}${BOLD}URL mods${RESET} ${DIM}(mods.txt)${RESET}"
  if [ -s "$MODS_FILE" ]; then
    while IFS= read -r line; do
      if [ -n "$line" ]; then
        echo -e "    ${GREEN}•${RESET} $line"
      fi
    done < "$MODS_FILE"
  else
    echo -e "    ${DIM}none${RESET}"
  fi
  echo ""
  echo -e "  ${CYAN}${BOLD}Modrinth mods${RESET} ${DIM}(.env)${RESET}"
  projects=$(get_modrinth_projects)
  if [ -n "${projects:-}" ]; then
    for s in $(echo "$projects" | tr ',' ' '); do
      echo -e "    ${GREEN}•${RESET} $s"
    done
  else
    echo -e "    ${DIM}none${RESET}"
  fi
  echo ""
  echo -e "  ${CYAN}${BOLD}Local mods${RESET} ${DIM}(data/mods/)${RESET}"
  if [ -d "$DATA_MODS_DIR" ]; then
    shopt -s nullglob
    local_jars=("$DATA_MODS_DIR"/*.jar)
    shopt -u nullglob
    if [ ${#local_jars[@]} -gt 0 ]; then
      for jar in "${local_jars[@]}"; do
        echo -e "    ${GREEN}•${RESET} $(basename "$jar")"
      done
    else
      echo -e "    ${DIM}none${RESET}"
    fi
  else
    echo -e "    ${DIM}none${RESET}"
  fi
}

do_remove() {
  echo ""
  items=()
  sources=()
  values=()

  if [ -s "$MODS_FILE" ]; then
    while IFS= read -r line; do
      if [ -n "$line" ]; then
        items+=("$line")
        sources+=("url")
        values+=("$line")
      fi
    done < "$MODS_FILE"
  fi

  projects=$(get_modrinth_projects)
  if [ -n "${projects:-}" ]; then
    for s in $(echo "$projects" | tr ',' ' '); do
      items+=("$s ${DIM}(modrinth)${RESET}")
      sources+=("modrinth")
      values+=("$s")
    done
  fi

  if [ -d "$DATA_MODS_DIR" ]; then
    shopt -s nullglob
    local_jars=("$DATA_MODS_DIR"/*.jar)
    shopt -u nullglob
    for jar in "${local_jars[@]}"; do
      items+=("$(basename "$jar") ${DIM}(local)${RESET}")
      sources+=("local")
      values+=("$jar")
    done
  fi

  if [ ${#items[@]} -eq 0 ]; then
    echo -e "  ${DIM}No mods to remove.${RESET}"
    return
  fi

  for i in "${!items[@]}"; do
    echo -e "  ${BOLD}$((i+1)))${RESET} ${items[$i]}"
  done
  echo ""
  echo -ne "  ${BOLD}Remove which?${RESET} [1-${#items[@]}, 0 to cancel]: "
  num=""
  read -r num

  if [ "${num:-0}" = "0" ]; then
    return
  fi
  if ! [[ "${num:-}" =~ ^[0-9]+$ ]] || [ "$num" -lt 1 ] || [ "$num" -gt "${#items[@]}" ]; then
    echo -e "  ${RED}Invalid selection.${RESET}"
    return
  fi

  idx=$((num - 1))
  src="${sources[$idx]}"
  val="${values[$idx]}"

  if [ "$src" = "url" ]; then
    tmpfile="$MODS_FILE.tmp"
    while IFS= read -r line; do
      if [ -n "$line" ] && [ "$line" != "$val" ]; then
        echo "$line"
      fi
    done < "$MODS_FILE" > "$tmpfile"
    mv "$tmpfile" "$MODS_FILE"
    echo -e "  ${GREEN}✓ Removed${RESET}"
  elif [ "$src" = "modrinth" ]; then
    current=$(get_modrinth_projects)
    new_value=$(echo ",$current," | sed "s/,$val,/,/" | sed 's/^,//' | sed 's/,$//')
    set_modrinth_projects "$new_value"
    echo -e "  ${GREEN}✓ Removed ${BOLD}$val${RESET}"
  elif [ "$src" = "local" ]; then
    rm -f "$val"
    echo -e "  ${GREEN}✓ Removed $(basename "$val")${RESET}"
  fi
}

if [ $# -gt 0 ]; then
  case "$1" in
    add)
      shift
      check_server_type
      for entry in "$@"; do
        add_entry "$entry"
      done
      ;;
    list)
      do_list
      ;;
    remove)
      do_remove
      ;;
    *)
      echo "Usage: ./mods.sh [add|list|remove] [urls or slugs...]"
      ;;
  esac
  exit 0
fi

echo ""
echo -e "  ${CYAN}${BOLD}╔════════════════════════════════════════╗${RESET}"
echo -e "  ${CYAN}${BOLD}║        Minecraft Mod Manager           ║${RESET}"
echo -e "  ${CYAN}${BOLD}╚════════════════════════════════════════╝${RESET}"
echo ""
while true; do
  echo -e "  ${BOLD}1)${RESET} Add mods"
  echo -e "  ${BOLD}2)${RESET} List mods"
  echo -e "  ${BOLD}3)${RESET} Remove mod"
  echo -e "  ${BOLD}4)${RESET} Exit"
  echo ""
  echo -ne "  ${CYAN}${BOLD}>${RESET} "
  choice=""
  read -r choice
  case "${choice:-}" in
    1) do_add ;;
    2) do_list ;;
    3) do_remove ;;
    4)
      echo ""
      echo -e "  ${DIM}Restart to apply: ./server.sh restart${RESET}"
      echo ""
      exit 0
      ;;
    *) echo -e "  ${RED}Invalid option${RESET}" ;;
  esac
  echo ""
  echo -e "  ${DIM}────────────────────────────────────────${RESET}"
  echo ""
done
