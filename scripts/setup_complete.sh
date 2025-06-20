#!/bin/bash
set -e

echo "🚀 Starting complete n8n setup process..."

# 1. システム起動
echo "1️⃣  Starting Docker containers..."
docker compose up -d

echo "⏳  Waiting for services to be ready..."
sleep 15

# PostgreSQLの健康状態をチェック
echo "🔍  Checking PostgreSQL health..."
until docker compose exec postgres pg_isready -U "$POSTGRES_USER" -d "$POSTGRES_DB" >/dev/null 2>&1; do
    echo "  Waiting for PostgreSQL..."
    sleep 5
done
echo "✅  PostgreSQL is ready"

# n8nの健康状態をチェック
echo "🔍  Checking n8n health..."
until curl -f http://localhost:5678/healthz >/dev/null 2>&1; do
    echo "  Waiting for n8n..."
    sleep 5
done
echo "✅  n8n is ready"

# 2. ワークフローインポート
echo "2️⃣  Importing workflows..."
./scripts/import_workflows.sh

echo ""
echo "🎉 Complete setup finished!"
echo ""
echo "📋 Next steps:"
echo "  1. Access n8n at: http://localhost:5678"
echo "  2. Set up GitHub webhook: http://your-server:5678/webhook/github-label-analysis"
echo "  3. Add labels to your GitHub repository:"
echo "     - workflow:ready-for-analysis"
echo "     - workflow:ready-for-impl" 
echo "     - workflow:ready-for-review"
echo ""
echo "🔧 For local development with ngrok:"
echo "  ngrok http 5678"
echo "  Then use the ngrok URL for GitHub webhook"