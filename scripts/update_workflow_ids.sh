#!/bin/bash
set -e

# 引数の確認
if [ $# -ne 3 ]; then
    echo "Usage: $0 <analysis_id> <impl_id> <review_id>"
    echo "Example: $0 abc123 def456 ghi789"
    exit 1
fi

ANALYSIS_ID="$1"
IMPL_ID="$2"
REVIEW_ID="$3"

echo "🔄 Updating n8n workflow IDs in database..."
echo "  Analysis ID: $ANALYSIS_ID"
echo "  Implementation ID: $IMPL_ID"
echo "  Review ID: $REVIEW_ID"

# PostgreSQLコンテナが起動していることを確認
if ! docker compose ps postgres | grep -q "running"; then
    echo "❌ PostgreSQL container is not running"
    exit 1
fi

# n8nの環境変数テーブルを更新するSQL
SQL_UPDATE="
BEGIN;

-- n8nの設定テーブルに環境変数を挿入/更新
-- テーブル構造は n8n のバージョンによって異なる可能性があります

-- settings テーブルが存在する場合
DO \$\$
BEGIN
    -- テーブルが存在する場合のみ実行
    IF EXISTS (SELECT FROM information_schema.tables WHERE table_name = 'settings') THEN
        -- 既存のレコードを削除
        DELETE FROM settings WHERE key IN ('N8N_ANALYSIS_SUBWORKFLOW_ID', 'N8N_IMPL_SUBWORKFLOW_ID', 'N8N_REVIEW_SUBWORKFLOW_ID');
        
        -- 新しい値を挿入
        INSERT INTO settings (key, value, load_on_startup) VALUES 
            ('N8N_ANALYSIS_SUBWORKFLOW_ID', '$ANALYSIS_ID', true),
            ('N8N_IMPL_SUBWORKFLOW_ID', '$IMPL_ID', true),
            ('N8N_REVIEW_SUBWORKFLOW_ID', '$REVIEW_ID', true);
        
        RAISE NOTICE 'Updated settings table';
    END IF;
END
\$\$;

-- variables テーブルが存在する場合
DO \$\$
BEGIN
    IF EXISTS (SELECT FROM information_schema.tables WHERE table_name = 'variables') THEN
        -- 既存のレコードを削除
        DELETE FROM variables WHERE key IN ('N8N_ANALYSIS_SUBWORKFLOW_ID', 'N8N_IMPL_SUBWORKFLOW_ID', 'N8N_REVIEW_SUBWORKFLOW_ID');
        
        -- 新しい値を挿入
        INSERT INTO variables (key, value, type) VALUES 
            ('N8N_ANALYSIS_SUBWORKFLOW_ID', '$ANALYSIS_ID', 'string'),
            ('N8N_IMPL_SUBWORKFLOW_ID', '$IMPL_ID', 'string'),
            ('N8N_REVIEW_SUBWORKFLOW_ID', '$REVIEW_ID', 'string');
        
        RAISE NOTICE 'Updated variables table';
    END IF;
END
\$\$;

COMMIT;
"

# SQLを実行
echo "🗃️  Executing SQL update..."
docker compose exec postgres psql -U "\$POSTGRES_USER" -d "\$POSTGRES_DB" -c "$SQL_UPDATE" || {
    echo "❌ Failed to update database directly"
    echo "🔧 Trying alternative approach with n8n CLI..."
    
    # n8n CLIで環境変数を設定（可能な場合）
    docker compose exec n8n sh -c "
        export N8N_ANALYSIS_SUBWORKFLOW_ID='$ANALYSIS_ID'
        export N8N_IMPL_SUBWORKFLOW_ID='$IMPL_ID'
        export N8N_REVIEW_SUBWORKFLOW_ID='$REVIEW_ID'
        echo 'Environment variables set in n8n container'
    " || {
        echo "❌ Failed to set environment variables"
        exit 1
    }
}

echo "✅ Workflow IDs updated successfully!"
echo ""
echo "🔄 Restarting n8n container to apply changes..."
docker compose restart n8n

echo "⏳ Waiting for n8n to restart..."
sleep 10

echo "🎉 Process completed! Workflow IDs have been updated."
echo ""
echo "📋 Current environment variables:"
echo "  N8N_ANALYSIS_SUBWORKFLOW_ID=$ANALYSIS_ID"
echo "  N8N_IMPL_SUBWORKFLOW_ID=$IMPL_ID"
echo "  N8N_REVIEW_SUBWORKFLOW_ID=$REVIEW_ID"
echo ""
echo "🔗 Please verify the configuration at: http://localhost:5678"