#!/usr/bin/env bash
# Deploy from the Mac: hajanek-api (+ Caddy + cloudflared) on JODA, forge voice
# worker on Spark. Idempotent: secrets, tunnel and DNS are created only once.
#
#   deploy/deploy.sh            # both
#   deploy/deploy.sh api        # JODA only
#   deploy/deploy.sh worker     # Spark only
#
# JODA: ~/deploy/Hajanek/{api,deploy}; .env and cloudflared/ creds stay there.
# Spark: ~/deploy/Hajanek/forge; forge/deploy/forge.env gets WORKER_TOKEN from JODA.
set -euo pipefail
ROOT=$(cd "$(dirname "$0")/.." && pwd)
JODA=${JODA:-joda} SPARK=${SPARK:-spark}
HOSTNAME_API=hajanek-api.ol1n.com
what=${1:-all}

deploy_api() {
  echo "== JODA: sync"
  ssh "$JODA" 'mkdir -p ~/deploy/Hajanek'
  rsync -a --delete --exclude bin/ --exclude .env --exclude 'cloudflared/*.json' \
    --exclude cloudflared/config.yml "$ROOT/api" "$ROOT/deploy" "$JODA":deploy/Hajanek/

  echo "== JODA: secrets, tunnel, compose up"
  ssh "$JODA" HOSTNAME_API="$HOSTNAME_API" bash -s <<'EOF'
set -euo pipefail
cd ~/deploy/Hajanek/deploy
if [ ! -f .env ]; then
  sed -e "s/^ADMIN_TOKEN=.*/ADMIN_TOKEN=$(openssl rand -hex 32)/" \
      -e "s/^WORKER_TOKEN=.*/WORKER_TOKEN=$(openssl rand -hex 32)/" .env.example > .env
  chmod 600 .env
  echo "created .env"
fi
if [ ! -f cloudflared/config.yml ]; then
  CERT=~/.cloudflared/cert.pem
  cloudflared tunnel --origincert "$CERT" info hajanek >/dev/null 2>&1 \
    || cloudflared tunnel --origincert "$CERT" create hajanek
  ID=$(cloudflared tunnel --origincert "$CERT" list -o json | python3 -c \
    'import sys,json;print(next(t["id"] for t in json.load(sys.stdin) if t["name"]=="hajanek"))')
  # cloudflared runs as nonroot in the container: creds must be readable.
  install -m 644 ~/.cloudflared/"$ID".json cloudflared/"$ID".json
  sed "s/<TUNNEL-ID>/$ID/g" cloudflared/config.yml.example > cloudflared/config.yml
  cloudflared tunnel --origincert "$CERT" route dns hajanek "$HOSTNAME_API"
  echo "tunnel hajanek = $ID"
fi
docker compose up -d --build
docker compose ps
EOF
}

deploy_worker() {
  echo "== Spark: sync"
  ssh "$SPARK" 'mkdir -p ~/deploy/Hajanek'
  rsync -a --delete --exclude bin/ --exclude work/ --exclude deploy/forge.env \
    "$ROOT/forge" "$SPARK":deploy/Hajanek/
  if ! ssh "$SPARK" 'test -f ~/deploy/Hajanek/forge/deploy/forge.env'; then
    TOKEN=$(ssh "$JODA" 'sed -n "s/^WORKER_TOKEN=//p" ~/deploy/Hajanek/deploy/.env')
    [ -n "$TOKEN" ] || { echo "no WORKER_TOKEN on JODA; deploy api first" >&2; exit 1; }
    ssh "$SPARK" "cd ~/deploy/Hajanek/forge/deploy && sed 's/^WORKER_TOKEN=.*/WORKER_TOKEN=$TOKEN/' forge.env.example > forge.env && chmod 600 forge.env"
    echo "created forge.env"
  fi
  echo "== Spark: compose up"
  ssh "$SPARK" 'cd ~/deploy/Hajanek/forge/deploy && docker compose -f docker-compose.worker.yml up -d --build && docker compose -f docker-compose.worker.yml ps'
}

case "$what" in
  api) deploy_api ;;
  worker) deploy_worker ;;
  all) deploy_api; deploy_worker ;;
  *) echo "usage: $0 [api|worker|all]" >&2; exit 2 ;;
esac

echo "== check"
curl -s -m 10 -o /dev/null -w "https://$HOSTNAME_API/v1/catalog/version → %{http_code}\n" \
  "https://$HOSTNAME_API/v1/catalog/version" || true
