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

# 環境確認（新規追加）
WSL_DISTRO_NAME=${WSL_DISTRO_NAME:-"Unknown"}
if [ "$WSL_DISTRO_NAME" = "Claude-Multi" ]; then
    echo -e "${GREEN}✓ Claude-Multi環境で実行中${NC}"
else
    echo -e "${YELLOW}⚠️  注意: 現在 $WSL_DISTRO_NAME 環境で実行しています${NC}"
    echo "Claude専用環境（Claude-Multi）の使用を推奨します。"
    echo ""
    echo -n "このまま続行しますか？ [y/N]: "
    read -r confirm
    if [ "$confirm" != "y" ] && [ "$confirm" != "Y" ]; then
        echo ""
        echo "Claude-Multi環境の作成方法："
        echo "https://github.com/ootakazuhiko/claude-multi#推奨claude専用wsl環境の作成"
        exit 0
    fi
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
    echo "以下のコマンドを実行してください："
    echo ""
    echo "  gh auth login"
    echo ""
    echo "認証方法："
    echo "1. 'Login with a web browser' を選択"
    echo "2. 表示されるコードをメモ"
    echo "3. Enterキーを押すとURLが表示される（ブラウザは開かない）"
    echo "4. Windows側のブラウザでURLを開く"
    echo "5. コードを入力して認証"
    echo ""
    echo -e "${YELLOW}※ 認証は後で行うこともできます${NC}"
else
    echo "✓ GitHub認証済み"
fi

echo ""
echo "🔑 SSH鍵設定..."
if [ ! -f ~/.ssh/id_ed25519 ]; then
    read -p "GitHubで使用するメールアドレス: " email
    ssh-keygen -t ed25519 -C "$email" -N "" -f ~/.ssh/id_ed25519
    
    # GitHub認証済みの場合のみSSH鍵を追加
    if gh auth status >/dev/null 2>&1; then
        # SSH鍵追加を試行し、スコープエラーを検出
        ssh_key_output=$(gh ssh-key add ~/.ssh/id_ed25519.pub --title "Claude Multi - $(hostname)" 2>&1)
        ssh_key_exit_code=$?
        
        if [ $ssh_key_exit_code -eq 0 ]; then
            echo "✓ SSH鍵をGitHubに追加しました"
        elif echo "$ssh_key_output" | grep -q "admin:public_key"; then
            echo -e "${YELLOW}⚠️  SSH鍵の追加にはadmin:public_keyスコープが必要です${NC}"
            echo ""
            echo "以下のコマンドでGitHub認証を更新してください："
            echo "  gh auth refresh -h github.com -s admin:public_key"
            echo ""
            echo "認証更新後、以下のコマンドでSSH鍵を追加できます："
            echo "  gh ssh-key add ~/.ssh/id_ed25519.pub --title \"Claude Multi - $(hostname)\""
        else
            echo -e "${YELLOW}⚠️  SSH鍵の追加に失敗しました${NC}"
            echo "エラー詳細: $ssh_key_output"
            echo ""
            echo "手動でSSH鍵を追加してください："
            echo "  gh ssh-key add ~/.ssh/id_ed25519.pub --title \"Claude Multi - $(hostname)\""
        fi
    else
        echo "✓ SSH鍵を作成しました"
        echo -e "${YELLOW}※ GitHub認証後、以下のコマンドでSSH鍵を追加してください：${NC}"
        echo "  gh ssh-key add ~/.ssh/id_ed25519.pub --title \"Claude Multi - $(hostname)\""
    fi
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
echo "   wsl -d Claude-Multi"
echo ""
echo "2. プロジェクトを作成:"
echo "   claude-manager quickstart myproject"
echo ""