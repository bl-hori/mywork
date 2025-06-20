#!/bin/bash
set -e

echo "Initializing PostgreSQL database for n8n..."

# 非root用のデータベースユーザーを作成
psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" <<-EOSQL
    -- 非root用ユーザーの作成
    CREATE USER $POSTGRES_NON_ROOT_USER WITH ENCRYPTED PASSWORD '$POSTGRES_NON_ROOT_PASSWORD';
    
    -- データベースの権限を付与
    GRANT ALL PRIVILEGES ON DATABASE $POSTGRES_DB TO $POSTGRES_NON_ROOT_USER;
    
    -- スキーマの権限を付与
    GRANT ALL ON SCHEMA public TO $POSTGRES_NON_ROOT_USER;
    
    -- 将来作成されるテーブルに対する権限を付与
    ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON TABLES TO $POSTGRES_NON_ROOT_USER;
    ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON SEQUENCES TO $POSTGRES_NON_ROOT_USER;
    ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON FUNCTIONS TO $POSTGRES_NON_ROOT_USER;
    
    -- スーパーユーザー権限を付与（n8nが必要とする場合）
    ALTER USER $POSTGRES_NON_ROOT_USER CREATEDB;
EOSQL

echo "PostgreSQL initialization completed successfully!"
echo "User '$POSTGRES_NON_ROOT_USER' has been created with appropriate permissions."