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

**方法1: 自動セットアップスクリプトを使用（推奨）**

PowerShell（管理者権限）でセットアップスクリプトをダウンロード：
```powershell
Invoke-WebRequest -Uri https://raw.githubusercontent.com/ootakazuhiko/claude-multi/main/setup-wsl.ps1 -OutFile setup-wsl.ps1
```

セットアップスクリプトを実行：
```powershell
.\setup-wsl.ps1
```

**方法2: 手動セットアップ**

1. Ubuntu 22.04を準備（既存の場合はスキップ）：
```powershell  
wsl --install -d Ubuntu-22.04
```

2. Ubuntu 22.04をエクスポート：
```powershell
wsl --export Ubuntu-22.04 ubuntu-base.tar
```

3. Claude-Multi用のディレクトリを作成：
```powershell
New-Item -ItemType Directory -Path "$env:USERPROFILE\WSL\Claude-Multi" -Force
```

4. Claude-Multi環境としてインポート：
```powershell
wsl --import Claude-Multi "$env:USERPROFILE\WSL\Claude-Multi" ubuntu-base.tar
```

5. 一時ファイルをクリーンアップ：
```powershell
Remove-Item ubuntu-base.tar
```

6. Claude-Multi環境に入る：
```powershell
wsl -d Claude-Multi
```

以降の手順はすべてClaude-Multi環境内で実行してください。

### 既存のWSL環境を使う場合

既存のUbuntu環境をそのまま使うこともできますが、専用環境の作成を推奨します。

## クイックスタート

### 方法1: Claude専用環境（推奨）

**ステップ1: Claude-Multi環境に入る**
```bash
wsl -d Claude-Multi
```

**ステップ2: 初回セットアップ（Claude-Multi環境内で実行）**

> ⚠️ **重要**: curl | bash では対話入力ができません。必ず以下の手順で実行してください

```bash
curl -fsSL https://raw.githubusercontent.com/ootakazuhiko/claude-multi/main/quick-setup.sh -o quick-setup.sh
bash quick-setup.sh
```

**ステップ3: WSL環境から一度出る**
```bash
exit
```

**ステップ4: WSLを再起動（PowerShellで実行）**
```powershell
wsl --shutdown
```

**ステップ5: Claude-Multi環境に再度入る**
```bash
wsl -d Claude-Multi
```

**ステップ6: プロジェクトを作成・起動**
```bash
claude-manager quickstart myproject
```

**ステップ7: VS Codeで開く（PowerShellから実行）**
```powershell
code --remote wsl+Claude-Multi /home/claude-myproject/workspace
```

### 方法2: 既存のWSL環境

**初回セットアップ（既存のUbuntu環境で実行）**

> ⚠️ **注意**: 専用環境の作成を推奨します

> ⚠️ **重要**: curl | bash では対話入力ができません。必ず以下の手順で実行してください

```bash
curl -fsSL https://raw.githubusercontent.com/ootakazuhiko/claude-multi/main/quick-setup.sh -o quick-setup.sh
bash quick-setup.sh
```

その後は方法1のステップ3以降と同様の手順を実行してください。

## 使い方

### 基本コマンド

**プロジェクト管理**

プロジェクトを作成して起動：
```bash
claude-manager quickstart <name>
```

プロジェクトを作成のみ（起動はしない）：
```bash
claude-manager create <name>
```

プロジェクトを削除：
```bash
claude-manager delete <name>
```

全プロジェクト一覧を表示：
```bash
claude-manager list
```

**サービス制御**

プロジェクトを起動：
```bash
claude-manager start <name>
```

プロジェクトを停止：
```bash
claude-manager stop <name>
```

プロジェクトを再起動：
```bash
claude-manager restart <name>
```

全プロジェクトを起動：
```bash
claude-manager start-all
```

全プロジェクトを停止：
```bash
claude-manager stop-all
```

**状態確認**

サービス状態を確認：
```bash
claude-manager status <name>
```

ヘルスチェックを実行：
```bash
claude-manager health <name>
```

ログを表示：
```bash
claude-manager logs <name>
```

### プロジェクトでの作業

**プロジェクト環境に入る**
```bash
sudo -u claude-myproject -i bash
```

**ワークスペースディレクトリに移動**
```bash
cd workspace
```

**GitHubリポジトリをクローン**
```bash
gh repo clone myorg/myrepo
```

**Podmanでコンテナを実行（dockerコマンドとして使用可能）**
```bash
docker run -d -p 3000:3000 my-app
```

## Windows Terminal統合

Claude-Multi環境を使用している場合、Windows Terminalに専用プロファイルを追加できます。

**settings.jsonに追加するプロファイル設定：**
```json
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

**PowerShellプロファイルに便利なエイリアスを追加**

`$PROFILE`ファイルに以下の関数を追加：

```powershell
function claude { wsl -d Claude-Multi claude-manager @args }
```

```powershell
function claude-code { 
    param($project)
    code --remote wsl+Claude-Multi /home/claude-$project/workspace
}
```

**使用例：**

プロジェクト一覧を表示：
```powershell
claude list
```

新しいプロジェクトを作成：
```powershell
claude quickstart myapp
```

VS Codeでプロジェクトを開く：
```powershell
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