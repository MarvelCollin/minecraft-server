#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")"

if [ -f .env ]; then
  echo ".env already exists, leaving it untouched."
else
  cp .env.example .env
  PASSWORD=$(openssl rand -hex 16 2>/dev/null || head -c32 /dev/urandom | od -An -tx1 | tr -d ' \n')
  sed -i "s/RCON_PASSWORD=changeme/RCON_PASSWORD=${PASSWORD}/" .env
  echo "Created .env with a randomly generated RCON_PASSWORD."
fi

echo ""
echo "Next steps:"
echo "  1. Open .env and review MOTD, DIFFICULTY, GAME_MODE, WHITELIST, OPS."
echo "  2. Start the server:  docker compose up -d"
echo "  3. Watch it boot:     docker compose logs -f minecraft"
