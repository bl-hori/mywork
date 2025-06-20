#!/bin/bash
set -e

echo "🚀 Starting n8n workflow import process..."

# n8nコンテナが起動していることを確認
if ! docker compose ps n8n | grep -q "running"; then
    echo "❌ n8n container is not running. Please start with: docker compose up -d"
    exit 1
fi

echo "✅ n8n container is running"

# ワークフローディレクトリの確認
WORKFLOW_DIR="./n8n/workflows"
if [ ! -d "$WORKFLOW_DIR" ]; then
    echo "❌ Workflow directory not found: $WORKFLOW_DIR"
    exit 1
fi

echo "📁 Found workflow directory: $WORKFLOW_DIR"

# ワークフローファイルをインポート
echo "📥 Importing workflows..."

# 各ワークフローファイルをインポート
for workflow_file in "$WORKFLOW_DIR"/*.json; do
    if [ -f "$workflow_file" ]; then
        filename=$(basename "$workflow_file")
        echo "  📄 Importing: $filename"
        
        # n8n CLIでワークフローをインポート
        docker compose exec n8n n8n import:workflow --input="$workflow_file" || {
            echo "❌ Failed to import $filename"
            continue
        }
        
        echo "  ✅ Successfully imported: $filename"
    fi
done

echo "📋 Listing all imported workflows..."
docker compose exec n8n n8n list:workflow

echo ""
echo "🔍 Getting workflow IDs for environment variables..."

# ワークフローIDを取得してファイルに保存
TEMP_FILE="/tmp/n8n_workflow_ids.txt"
docker compose exec n8n n8n list:workflow --output=json > "$TEMP_FILE" 2>/dev/null || {
    echo "❌ Failed to get workflow list in JSON format"
    echo "🔧 Please manually check workflow IDs with: docker compose exec n8n n8n list:workflow"
    exit 1
}

# JSONからIDを抽出
if command -v jq >/dev/null 2>&1; then
    echo "📊 Extracting workflow IDs..."
    
    ANALYSIS_ID=$(jq -r '.[] | select(.name == "Issue Analysis Subworkflow") | .id' "$TEMP_FILE" 2>/dev/null || echo "")
    IMPL_ID=$(jq -r '.[] | select(.name == "Implementation Execution Subworkflow") | .id' "$TEMP_FILE" 2>/dev/null || echo "")
    REVIEW_ID=$(jq -r '.[] | select(.name == "Review Execution Subworkflow") | .id' "$TEMP_FILE" 2>/dev/null || echo "")
    
    echo ""
    echo "🆔 Workflow IDs detected:"
    echo "  Analysis Subworkflow: ${ANALYSIS_ID:-'Not found'}"
    echo "  Implementation Subworkflow: ${IMPL_ID:-'Not found'}"
    echo "  Review Subworkflow: ${REVIEW_ID:-'Not found'}"
    
    # 環境変数を更新するためのスクリプトを実行
    if [ -n "$ANALYSIS_ID" ] && [ -n "$IMPL_ID" ] && [ -n "$REVIEW_ID" ]; then
        echo ""
        echo "🔄 Updating environment variables in n8n container..."
        ./scripts/update_workflow_ids.sh "$ANALYSIS_ID" "$IMPL_ID" "$REVIEW_ID"
    else
        echo "⚠️  Some workflow IDs could not be found. Please check manually."
    fi
else
    echo "⚠️  jq not found. Please install jq or manually extract workflow IDs from:"
    cat "$TEMP_FILE"
fi

# 一時ファイルを削除
rm -f "$TEMP_FILE"

echo ""
echo "✨ Workflow import process completed!"
echo "🔗 Access n8n at: http://localhost:5678"
echo "📝 Please verify all workflows are active and properly configured."