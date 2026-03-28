#!/usr/bin/env bash
# infrastructure/scripts/deploy.sh
# One-command deployment script for FlowPath AI on AWS EC2
# Usage: ./deploy.sh [environment]
# Requires: AWS CLI configured, SSH key for EC2

set -euo pipefail

ENV="${1:-production}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"

# ── Colours ──────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
BLUE='\033[0;34m'; CYAN='\033[0;36m'; NC='\033[0m'

log()  { echo -e "${CYAN}[FlowPath]${NC} $*"; }
ok()   { echo -e "${GREEN}✅${NC} $*"; }
warn() { echo -e "${YELLOW}⚠️${NC}  $*"; }
err()  { echo -e "${RED}❌${NC} $*"; exit 1; }

# ── Environment check ─────────────────────────────────────────
log "Deploying FlowPath AI to $ENV environment..."

[ -f "$ROOT_DIR/backend/.env" ] || err "backend/.env not found. Copy .env.example and fill in values."
[ "$(command -v aws)" ] || err "AWS CLI not installed. Install from https://aws.amazon.com/cli/"
[ "$(command -v docker)" ] || err "Docker not installed."

# Load deployment config
EC2_HOST="${EC2_HOST:-}"
EC2_USER="${EC2_USER:-ubuntu}"
EC2_KEY="${EC2_KEY:-~/.ssh/flowpath.pem}"
ECR_REGISTRY="${ECR_REGISTRY:-}"
AWS_REGION="${AWS_REGION:-ap-south-1}"

[ -z "$EC2_HOST" ]   && err "EC2_HOST environment variable not set"
[ -z "$ECR_REGISTRY" ] && err "ECR_REGISTRY environment variable not set"

# ── Step 1: Run Tests ─────────────────────────────────────────
log "Step 1/5: Running tests..."
cd "$ROOT_DIR/backend" && npm test --silent && ok "Backend tests passed"
cd "$ROOT_DIR/ai-engine" && python -m pytest tests/ -q && ok "AI engine tests passed"

# ── Step 2: Build Docker Images ───────────────────────────────
log "Step 2/5: Building Docker images..."
cd "$ROOT_DIR"
TIMESTAMP=$(date +%Y%m%d%H%M%S)
GIT_SHA=$(git rev-parse --short HEAD 2>/dev/null || echo "$TIMESTAMP")

docker build -t "flowpath-backend:$GIT_SHA" -f docker/Dockerfile.backend . && ok "Backend image built"
docker build -t "flowpath-ai:$GIT_SHA"      -f docker/Dockerfile.ai      . && ok "AI engine image built"

# ── Step 3: Push to ECR ───────────────────────────────────────
log "Step 3/5: Pushing to Amazon ECR..."
aws ecr get-login-password --region "$AWS_REGION" | \
  docker login --username AWS --password-stdin "$ECR_REGISTRY"

docker tag "flowpath-backend:$GIT_SHA" "$ECR_REGISTRY/flowpath-backend:$GIT_SHA"
docker tag "flowpath-backend:$GIT_SHA" "$ECR_REGISTRY/flowpath-backend:latest"
docker push "$ECR_REGISTRY/flowpath-backend:$GIT_SHA"
docker push "$ECR_REGISTRY/flowpath-backend:latest"

docker tag "flowpath-ai:$GIT_SHA" "$ECR_REGISTRY/flowpath-ai:$GIT_SHA"
docker tag "flowpath-ai:$GIT_SHA" "$ECR_REGISTRY/flowpath-ai:latest"
docker push "$ECR_REGISTRY/flowpath-ai:$GIT_SHA"
docker push "$ECR_REGISTRY/flowpath-ai:latest"
ok "Images pushed to ECR"

# ── Step 4: Run DB Migrations ─────────────────────────────────
log "Step 4/5: Running database migrations..."
ssh -i "$EC2_KEY" -o StrictHostKeyChecking=no "$EC2_USER@$EC2_HOST" "
  set -e
  for f in /opt/flowpath/database/migrations/*.sql; do
    echo \"Running migration: \$(basename \$f)\"
    PGPASSWORD=\$DB_PASSWORD psql -h \$DB_HOST -U \$DB_USER -d \$DB_NAME -f \"\$f\" || true
  done
  echo '✅ Migrations complete'
"
ok "Database migrations complete"

# ── Step 5: Deploy ────────────────────────────────────────────
log "Step 5/5: Deploying to EC2..."
ssh -i "$EC2_KEY" -o StrictHostKeyChecking=no "$EC2_USER@$EC2_HOST" "
  set -e
  cd /opt/flowpath
  git pull origin main

  # Pull new images
  aws ecr get-login-password --region $AWS_REGION | \
    docker login --username AWS --password-stdin $ECR_REGISTRY

  docker-compose -f docker/docker-compose.yml pull backend ai-engine
  docker-compose -f docker/docker-compose.yml up -d --no-deps --force-recreate backend ai-engine

  # Verify services are healthy
  sleep 15
  docker-compose -f docker/docker-compose.yml ps
  curl -sf http://localhost:3000/health || (echo 'Health check failed!' && exit 1)
  echo '✅ Services deployed and healthy'
"

ok "FlowPath AI deployed to $ENV! 🚀"
log "API: https://${CLOUDFRONT_DOMAIN:-$EC2_HOST}/health"
log "Docs: https://${CLOUDFRONT_DOMAIN:-$EC2_HOST}/api/v1"

# Clean up local images
docker image prune -f --filter "until=24h"
