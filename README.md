# Claude Multi - 複数Claude Code環境管理ツール

個人でClaude Codeを複数、簡単に動かすためのシンプルな環境構築ツールです。

## 特徴

- 🚀 **最速セットアップ**: ワンライナーで環境構築
- 📦 **簡単管理**: 統一されたコマンドで全操作
- 🔒 **完全分離**: プロジェクトごとに独立した環境
- 🐙 **GitHub連携**: 開発フローに最適化

## 必要要件

- Windows 10/11 + WSL2 (Ubuntu推奨)
- インターネット接続

## クイックスタート

```bash
# 1. 初回セットアップ（一度だけ）
curl -fsSL https://raw.githubusercontent.com/ootakazuhiko/claude-multi/main/quick-setup.sh | bash

# 2. WSL再起動
exit
# PowerShellで: wsl --shutdown
# 再度WSLに入る

# 3. プロジェクト作成・起動
claude-manager quickstart myproject

# 4. VS Codeで開く
code --remote wsl+Ubuntu /home/claude-myproject/workspace
```

## 使い方

### 基本コマンド

```bash
# プロジェクト管理
claude-manager quickstart <name>  # 作成から起動まで一発
claude-manager create <name>      # プロジェクト作成のみ
claude-manager delete <name>      # プロジェクト削除
claude-manager list               # 全プロジェクト一覧

# サービス制御
claude-manager start <name>       # 起動
claude-manager stop <name>        # 停止
claude-manager restart <name>     # 再起動
claude-manager start-all          # 全プロジェクト起動
claude-manager stop-all           # 全プロジェクト停止

# 状態確認
claude-manager status <name>      # サービス状態
claude-manager health <name>      # ヘルスチェック
claude-manager logs <name>        # ログ表示
```

### プロジェクトでの作業

```bash
# プロジェクト環境に入る
sudo -u claude-myproject -i bash

# リポジトリをクローン
cd workspace
gh repo clone myorg/myrepo

# Podmanでコンテナ実行（dockerコマンドが使える）
docker run -d -p 3000:3000 my-app
```

## アーキテクチャ

各プロジェクトは独立したLinuxユーザーとして実行され、以下を持ちます：

- 独立したホームディレクトリ (`/home/claude-{project}`)
- 独立したPodman環境（rootless）
- systemdサービスとして管理
- GitHub認証情報の共有（元ユーザーから）

## トラブルシューティング

[詳細なトラブルシューティングガイド](docs/troubleshooting.md)を参照してください。

## ライセンス

MIT License

## 貢献

Issue報告やPull Requestを歓迎します！