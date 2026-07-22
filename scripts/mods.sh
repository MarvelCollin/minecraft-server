#!/usr/bin/env bash
set -uo pipefail

cd "$(dirname "$0")/.."

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

print_header() {
  echo ""
  echo -e "  ${CYAN}${BOLD}╔════════════════════════════════════════╗${RESET}"
  echo -e "  ${CYAN}${BOLD}║        Minecraft Mod Manager           ║${RESET}"
  echo -e "  ${CYAN}${BOLD}╚════════════════════════════════════════╝${RESET}"
  echo ""
}

print_line() {
  echo -e "  ${DIM}────────────────────────────────────────${RESET}"
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

do_add_url() {
  echo ""
  echo -e "  ${BOLD}Paste URLs${RESET} ${DIM}(one per line, empty line to finish)${RESET}"
  count=0
  while true; do
    echo -ne "  ${CYAN}>${RESET} "
    url=""
    read -r url
    if [ -z "${url:-}" ]; then
      break
    fi
    if grep -qxF "$url" "$MODS_FILE" 2>/dev/null; then
      echo -e "    ${YELLOW}already exists${RESET}"
    else
      echo "$url" >> "$MODS_FILE"
      echo -e "    ${GREEN}✓ added${RESET}"
      count=$((count + 1))
    fi
  done
  if [ $count -gt 0 ]; then
    echo ""
    echo -e "  ${GREEN}${BOLD}$count mod(s) added to mods.txt${RESET}"
  fi
}

do_add_modrinth() {
  echo ""
  if [ ! -f "$ENV_FILE" ]; then
    echo -e "  ${RED}.env not found. Run scripts/setup.sh first.${RESET}"
    return
  fi
  echo -e "  ${BOLD}Enter Modrinth slugs${RESET} ${DIM}(space or comma separated)${RESET}"
  echo -e "  ${DIM}e.g. sodium lithium starlight${RESET}"
  echo -ne "  ${CYAN}>${RESET} "
  input=""
  read -r input
  if [ -z "${input:-}" ]; then
    return
  fi
  current=$(get_modrinth_projects)
  count=0
  for slug in $(echo "${input}" | tr ',' ' '); do
    slug=$(echo "$slug" | tr -d ' ')
    if [ -z "$slug" ]; then
      continue
    fi
    if [ -n "${current:-}" ] && echo ",$current," | grep -q ",$slug,"; then
      echo -e "    ${YELLOW}$slug already exists${RESET}"
      continue
    fi
    if [ -z "${current:-}" ]; then
      current="$slug"
    else
      current="$current,$slug"
    fi
    echo -e "    ${GREEN}✓ $slug${RESET}"
    count=$((count + 1))
  done
  if [ $count -gt 0 ]; then
    set_modrinth_projects "$current"
    echo ""
    echo -e "  ${GREEN}${BOLD}$count mod(s) added to Modrinth projects${RESET}"
  fi
}

do_add_file() {
  echo ""
  mkdir -p "$MODS_DIR"

  shopt -s nullglob
  jars=("$MODS_DIR"/*.jar)
  shopt -u nullglob

  if [ ${#jars[@]} -eq 0 ]; then
    echo -e "  ${DIM}Drop .jar files into the ${RESET}${BOLD}mods/${RESET}${DIM} folder, then select this option again.${RESET}"
    echo -e "  ${DIM}Accepts mods from any source (CurseForge, Modrinth, GitHub, etc.)${RESET}"
    return
  fi

  echo -e "  ${BOLD}Found in mods/:${RESET}"
  for i in "${!jars[@]}"; do
    echo -e "    ${BOLD}$((i+1)).${RESET} $(basename "${jars[$i]}")"
  done
  echo ""
  echo -ne "  ${BOLD}Install all to server?${RESET} [Y/n]: "
  confirm=""
  read -r confirm

  if [[ "${confirm:-Y}" =~ ^[Yy]?$ ]]; then
    mkdir -p "$DATA_MODS_DIR"
    count=0
    for jar in "${jars[@]}"; do
      cp "$jar" "$DATA_MODS_DIR/"
      echo -e "    ${GREEN}✓ $(basename "$jar")${RESET}"
      count=$((count + 1))
    done
    echo ""
    echo -e "  ${GREEN}${BOLD}$count mod(s) installed to data/mods/${RESET}"
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

  echo -e "  ${CYAN}${BOLD}Modrinth mods${RESET} ${DIM}(.env MODRINTH_PROJECTS)${RESET}"
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
    echo -e "    ${DIM}server not started yet${RESET}"
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
        items+=("url  │ $line")
        sources+=("url")
        values+=("$line")
      fi
    done < "$MODS_FILE"
  fi

  projects=$(get_modrinth_projects)
  if [ -n "${projects:-}" ]; then
    for s in $(echo "$projects" | tr ',' ' '); do
      items+=("mr   │ $s")
      sources+=("modrinth")
      values+=("$s")
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
  fi
}

if [ $# -gt 0 ]; then
  case "$1" in
    add)
      shift
      for url in "$@"; do
        if grep -qxF "$url" "$MODS_FILE" 2>/dev/null; then
          echo "Already exists: $url"
        else
          echo "$url" >> "$MODS_FILE"
          echo "Added: $url"
        fi
      done
      ;;
    remove)
      shift
      for url in "$@"; do
        if grep -qxF "$url" "$MODS_FILE" 2>/dev/null; then
          tmpfile="$MODS_FILE.tmp"
          while IFS= read -r line; do
            if [ -n "$line" ] && [ "$line" != "$url" ]; then
              echo "$line"
            fi
          done < "$MODS_FILE" > "$tmpfile"
          mv "$tmpfile" "$MODS_FILE"
          echo "Removed: $url"
        else
          echo "Not found: $url"
        fi
      done
      ;;
    list)
      do_list
      ;;
    *)
      echo "Usage: ./scripts/mods.sh [add|remove|list] [urls...]"
      ;;
  esac
  exit 0
fi

print_header
while true; do
  echo -e "  ${BOLD}1)${RESET} Add mod by URL          ${DIM}any download link${RESET}"
  echo -e "  ${BOLD}2)${RESET} Add mod from Modrinth   ${DIM}by slug name${RESET}"
  echo -e "  ${BOLD}3)${RESET} Add mod from file       ${DIM}drop .jar into mods/${RESET}"
  echo -e "  ${BOLD}4)${RESET} List all mods"
  echo -e "  ${BOLD}5)${RESET} Remove a mod"
  echo -e "  ${BOLD}6)${RESET} Exit"
  echo ""
  echo -ne "  ${CYAN}${BOLD}>${RESET} "
  choice=""
  read -r choice
  case "${choice:-}" in
    1) do_add_url ;;
    2) do_add_modrinth ;;
    3) do_add_file ;;
    4) do_list ;;
    5) do_remove ;;
    6)
      echo ""
      echo -e "  ${DIM}Restart to apply: docker compose restart minecraft${RESET}"
      echo ""
      exit 0
      ;;
    *) echo -e "  ${RED}  Invalid option.${RESET}" ;;
  esac
  echo ""
  print_line
  echo ""
done
