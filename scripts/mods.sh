#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

MODS_FILE="mods.txt"

case "${1:-}" in
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
    echo ""
    echo "Restart to apply: docker compose restart minecraft"
    ;;
  remove)
    shift
    for url in "$@"; do
      if grep -qxF "$url" "$MODS_FILE" 2>/dev/null; then
        grep -vxF "$url" "$MODS_FILE" > "$MODS_FILE.tmp" && mv "$MODS_FILE.tmp" "$MODS_FILE"
        echo "Removed: $url"
      else
        echo "Not found: $url"
      fi
    done
    echo ""
    echo "Restart to apply: docker compose restart minecraft"
    ;;
  list)
    if [ ! -s "$MODS_FILE" ]; then
      echo "No mods configured in $MODS_FILE"
    else
      nl -ba "$MODS_FILE"
    fi
    ;;
  *)
    echo "Usage: ./scripts/mods.sh {add|remove|list} [urls...]"
    echo ""
    echo "Examples:"
    echo "  ./scripts/mods.sh add https://example.com/mod.jar"
    echo "  ./scripts/mods.sh remove https://example.com/mod.jar"
    echo "  ./scripts/mods.sh list"
    echo ""
    echo "Set SERVER_TYPE in .env to FORGE or FABRIC to enable mod support."
    echo "Set MODRINTH_PROJECTS in .env for Modrinth mods (e.g. sodium,lithium)."
    ;;
esac
