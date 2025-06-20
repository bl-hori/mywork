# Claude Code n8n GitHub自動化システム

Claude CodeとN8nを使用したGitHubのissue管理・開発フローの自動化システムです。ラベルベースでissueの分析、実装、レビューを自動実行します。

## 機能概要

- **Issue分析**: `workflow:ready-for-analysis`ラベルでClaude Code actionによる自動分析
- **自動実装**: `workflow:ready-for-impl`ラベルでPR作成・実装
- **自動レビュー**: `workflow:ready-for-review`ラベルでコードレビュー
- PostgreSQLによるデータ永続化
- GitHubのwebhookによるリアルタイム連携

## 前提条件

- Docker & Docker Compose
- GitHub Personal Access Token (repo権限)
- Anthropic API キー（Claude Code action用）
- GitHubリポジトリでClaude Code actionが有効化されていること

## セットアップ

### 1. 環境変数の設定

```bash
# .envファイルを作成
cp .env.example .env
```

`.env`ファイルに以下を設定：

```env
# PostgreSQL設定
POSTGRES_USER=n8n_user
POSTGRES_PASSWORD=your_secure_password
POSTGRES_DB=n8n_db
POSTGRES_NON_ROOT_USER=n8n_app
POSTGRES_NON_ROOT_PASSWORD=your_app_password

# GitHub設定
GITHUB_TOKEN=your_github_personal_access_token
GITHUB_REPO_OWNER=your_username
GITHUB_REPO_NAME=your_repository

# Claude Code設定（GitHub Actionsで@claudeメンション用）
ANTHROPIC_API_KEY=your_anthropic_api_key
```

### 2. PostgreSQL初期化

`init-data.sh`ファイルが既に含まれています（docker-compose.ymlで自動実行されます）。

### 3. システム起動

```bash
# コンテナ起動
docker-compose up -d

# ログ確認
docker-compose logs -f n8n
```

n8nは `http://localhost:5678` でアクセス可能です。

## クイックスタート（推奨）

完全自動セットアップ：

```bash
# 全自動セットアップ（推奨）
./scripts/setup_complete.sh
```

このスクリプトが以下を自動実行します：
1. Docker Compose でサービス起動
2. PostgreSQL とn8nの起動待機
3. ワークフローの自動インポート
4. サブワークフローIDの自動取得・設定
5. n8n環境変数の自動更新

## n8nワークフローのインポート

### 自動インポート（個別実行）

システム起動後、以下のスクリプトでワークフローを自動インポート：

```bash
# ワークフローインポートのみ
./scripts/import_workflows.sh
```

このスクリプトが以下を実行：
- 全ワークフローファイルの自動インポート
- サブワークフローIDの自動取得
- PostgreSQL環境変数テーブルの自動更新
- n8nコンテナの再起動

### 手動インポート

1. n8n管理画面 (`http://localhost:5678`) にアクセス
2. 各ワークフローファイルをインポート：
   - `n8n/workflows/Label_Manager_Flow.json` (メインワークフロー)
   - `n8n/workflows/Issue_Analysis_Subworkflow.json`
   - `n8n/workflows/Implementation_Execution_Subworkflow.json`
   - `n8n/workflows/Review_Execution_Subworkflow.json`

3. 各サブワークフローのIDを確認し、環境変数を更新：
   ```bash
   # docker-compose.ymlの環境変数を実際のIDに更新
   N8N_ANALYSIS_SUBWORKFLOW_ID=実際のワークフローID
   N8N_IMPL_SUBWORKFLOW_ID=実際のワークフローID  
   N8N_REVIEW_SUBWORKFLOW_ID=実際のワークフローID
   ```

## GitHubのWebhook設定

### 1. Webhookの作成

GitHubリポジトリの Settings > Webhooks で新しいwebhookを作成：

- **Payload URL**: `http://your-server:5678/webhook/github-label-analysis`
- **Content type**: `application/json`
- **Secret**: 任意（推奨）
- **Events**: `Issues`, `Pull requests`, `Issue comments`

### 2. ngrokを使ったローカル開発

ローカル開発時はngrokでトンネルを作成：

```bash
# ngrokでポート5678を公開
ngrok http 5678

# 表示されたURLをGitHub webhookに設定
# 例: https://abc123.ngrok.io/webhook/github-label-analysis
```

## 使用方法

### ワークフローの実行

1. **分析フェーズ**: 
   - Issueに `workflow:ready-for-analysis` ラベルを追加
   - `@claude`メンション（Claude Code action）が自動でissueを分析し実装計画を作成
   - 完了後、`workflow:ready-for-impl` ラベルが自動追加

2. **実装フェーズ**:
   - `workflow:ready-for-impl` ラベルで`@claude`メンションによるPR作成・実装が自動実行
   - 完了後、`workflow:ready-for-review` ラベルが自動追加

3. **レビューフェーズ**:
   - `workflow:ready-for-review` ラベルで`@claude`メンションによる自動レビューが実行

### ラベル管理

以下のラベルをGitHubリポジトリに作成してください：

```bash
# GitHubでラベル作成
gh label create "workflow:ready-for-analysis" --color "0e8a16"
gh label create "workflow:ready-for-impl" --color "fbca04"  
gh label create "workflow:ready-for-review" --color "d93f0b"
```

## トラブルシューティング

### ワークフローが実行されない

1. webhook URLとイベント設定を確認
2. n8nのログを確認: `docker-compose logs n8n`
3. PostgreSQL接続を確認: `docker-compose logs postgres`

### データベース接続エラー

```bash
# PostgreSQLコンテナを再起動
docker-compose restart postgres

# データベース初期化のやり直し
docker-compose down -v
docker-compose up -d
```

### ワークフローIDの確認

```bash
# n8n CLIでワークフロー一覧を確認
docker-compose exec n8n n8n list:workflow
```

## 設定ファイル

- `docker-compose.yml`: コンテナ構成とサービス定義
- `n8n/workflows/`: n8nワークフロー定義ファイル
- `init-data.sh`: PostgreSQL初期化用スクリプト（実行権限付与済み）
- `scripts/`: 自動化スクリプト群
  - `setup_complete.sh`: 完全自動セットアップ
  - `import_workflows.sh`: ワークフロー自動インポート
  - `update_workflow_ids.sh`: サブワークフローID自動更新

## ライセンス

MIT License