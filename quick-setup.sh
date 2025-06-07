#!/bin/bash
set -e

echo "======================================"
echo "Claude Multi - 初回セットアップ"
echo "======================================"
echo ""

# 色定義
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

# エラーハンドラ
error_exit() {
    echo -e "${RED}エラー: $1${NC}" >&2
    exit 1
}

# WSL2チェック
if [ ! -f /proc/sys/fs/binfmt_misc/WSLInterop ]; then
    error_exit "WSL2環境で実行してください"
fi

echo "📦 必要なパッケージをインストール中..."
sudo apt update || error_exit "apt updateに失敗しました"
sudo apt install -y podman git gh curl || error_exit "パッケージインストールに失敗しました"

echo ""
echo "⚙️  systemdを有効化..."
if ! grep -q "systemd=true" /etc/wsl.conf 2>/dev/null; then
    sudo tee /etc/wsl.conf > /dev/null <<EOF
[boot]
systemd=true
EOF
    echo -e "${YELLOW}⚠️  WSLの再起動が必要です${NC}"
fi

echo ""
echo "🤖 Claude Codeをインストール中..."
if ! command -v claude >/dev/null 2>&1; then
    curl -fsSL https://claude.ai/install.sh | sudo bash || echo -e "${YELLOW}Claude Codeのインストールはスキップされました${NC}"
else
    echo "✓ Claude Codeは既にインストールされています"
fi

echo ""
echo "🔐 GitHub認証設定..."
if ! gh auth status >/dev/null 2>&1; then
    echo "GitHub認証が必要です。"
    gh auth login
else
    echo "✓ GitHub認証済み"
fi

echo ""
echo "🔑 SSH鍵設定..."
if [ ! -f ~/.ssh/id_ed25519 ]; then
    read -p "GitHubで使用するメールアドレス: " email
    ssh-keygen -t ed25519 -C "$email" -N "" -f ~/.ssh/id_ed25519
    gh ssh-key add ~/.ssh/id_ed25519.pub --title "Claude Multi - $(hostname)"
else
    echo "✓ SSH鍵は既に存在します"
fi

echo ""
echo "📂 管理スクリプトをインストール中..."
sudo mkdir -p /opt/claude-shared

# claude-manager.shをダウンロード
sudo curl -fsSL -o /opt/claude-shared/claude-manager.sh \
    https://raw.githubusercontent.com/ootakazuhiko/claude-multi/main/claude-manager.sh \
    || error_exit "claude-manager.shのダウンロードに失敗しました"

sudo chmod +x /opt/claude-shared/claude-manager.sh

# エイリアス設定
if ! grep -q "alias claude-manager" ~/.bashrc; then
    echo 'alias claude-manager="sudo /opt/claude-shared/claude-manager.sh"' >> ~/.bashrc
fi

echo ""
echo -e "${GREEN}✅ セットアップ完了！${NC}"
echo ""
echo "次の手順:"
echo "1. WSLを再起動してください:"
echo "   exit"
echo "   # PowerShellで: wsl --shutdown"
echo "   # 再度WSLに入る"
echo ""
echo "2. プロジェクトを作成:"
echo "   claude-manager quickstart myproject"
echo ""