# Claude Multi - 複数Claude Code環境管理ツール

個人でClaude Codeを複数、簡単に動かすためのシンプルな環境構築ツールです。

## 特徴

- 🚀 **簡単セットアップ**: スクリプトで環境を自動構築
- 📦 **統一管理**: シンプルなコマンドで全操作
- 🔒 **完全分離**: プロジェクトごとに独立した環境
- 🐙 **GitHub連携**: 開発フローに最適化

## 必要要件

- Windows 10/11 + WSL2 (Ubuntu推奨)
- インターネット接続

## 推奨：Claude専用WSL環境の作成

通常の開発環境を汚さないために、Claude Code専用のWSL環境を作成することを推奨します。

### 専用環境のセットアップ（推奨）

```powershell
# PowerShell（管理者権限）で実行

# 1. Ubuntu 22.04をインストール
wsl --install -d Ubuntu-22.04

# 2. 一旦エクスポート
wsl --export Ubuntu-22.04 ubuntu-base.tar

# 3. Claude-Multi という名前で再インポート  
New-Item -ItemType Directory -Path "$env:USERPROFILE\WSL\Claude-Multi" -Force
wsl --import Claude-Multi "$env:USERPROFILE\WSL\Claude-Multi" ubuntu-base.tar

# 4. 元のUbuntu-22.04を削除
wsl --unregister Ubuntu-22.04
Remove-Item ubuntu-base.tar

# 5. Claude-Multi環境に入る
wsl -d Claude-Multi
```

以降の手順はすべてClaude-Multi環境内で実行してください。

### 既存のWSL環境を使う場合

既存のUbuntu環境をそのまま使うこともできますが、専用環境の作成を推奨します。

## クイックスタート

### 方法1: Claude専用環境（推奨）

```bash
# 0. Claude-Multi環境を作成（上記参照）して入る
wsl -d Claude-Multi

# 1. 初回セットアップ（Claude-Multi環境内で実行）
curl -fsSL https://raw.githubusercontent.com/ootakazuhiko/claude-multi/main/quick-setup.sh | bash

# 2. WSL再起動
exit
# PowerShellで: wsl --shutdown
# 再度Claude-Multi環境に入る: wsl -d Claude-Multi

# 3. プロジェクト作成・起動
claude-manager quickstart myproject

# 4. VS Codeで開く（PowerShellから）
code --remote wsl+Claude-Multi /home/claude-myproject/workspace
```

### 方法2: 既存のWSL環境

```bash
# 既存のUbuntu環境で実行（非推奨）
curl -fsSL https://raw.githubusercontent.com/ootakazuhiko/claude-multi/main/quick-setup.sh | bash
# 以下同様...
```

## 使い方

### 基本コマンド

```bash
# プロジェクト管理
claude-manager quickstart <name>  # プロジェクト作成と起動
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

## Windows Terminal統合

Claude-Multi環境を使用している場合、Windows Terminalに専用プロファイルを追加できます：

```json
// settings.json
{
  "profiles": {
    "list": [
      {
        "guid": "{生成したGUID}",
        "name": "Claude Multi 🤖",
        "commandline": "wsl.exe -d Claude-Multi",
        "icon": "🤖",
        "startingDirectory": "~"
      }
    ]
  }
}
```

PowerShellで便利なエイリアスも設定できます：

```powershell
# $PROFILE に追加
function claude { wsl -d Claude-Multi claude-manager @args }
function claude-code { 
    param($project)
    code --remote wsl+Claude-Multi /home/claude-$project/workspace
}

# 使用例
claude list
claude quickstart myapp
claude-code myapp
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