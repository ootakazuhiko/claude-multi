#!/bin/bash
set -e

# 割り込み時のクリーンアップ設定
trap cleanup_on_error INT TERM ERR

echo "======================================"
echo "Claude Multi - 初回セットアップ"
echo "======================================"
echo ""

# 色定義
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

# 入力値検証関数
validate_email() {
    local email="$1"
    if [ -z "$email" ]; then
        echo -e "${RED}エラー: メールアドレスが入力されていません${NC}" >&2
        return 1
    fi
    
    # 基本的なメールアドレス形式チェック
    if ! [[ "$email" =~ ^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$ ]]; then
        echo -e "${RED}エラー: 有効なメールアドレスを入力してください${NC}" >&2
        return 1
    fi
    
    return 0
}

# セキュアなダウンロード関数
secure_download() {
    local url="$1"
    local output="$2"
    local expected_pattern="$3"  # オプション: 期待されるファイル内容のパターン
    
    echo "📥 ダウンロード中: $(basename "$output")"
    
    if ! curl -fsSL "$url" -o "$output"; then
        echo -e "${RED}エラー: ダウンロードに失敗しました: $url${NC}" >&2
        return 1
    fi
    
    # 基本的な内容チェック（shellscriptヘッダーの確認）
    if [ -n "$expected_pattern" ] && ! head -5 "$output" | grep -q "$expected_pattern"; then
        echo -e "${RED}エラー: ダウンロードしたファイルが期待された形式ではありません${NC}" >&2
        rm -f "$output"
        return 1
    fi
    
    return 0
}

# エラーハンドラ
error_exit() {
    echo -e "${RED}エラー: $1${NC}" >&2
    cleanup_on_error
    exit 1
}

# エラー時のクリーンアップ
cleanup_on_error() {
    echo "クリーンアップ中..."
    # 一時ファイルのクリーンアップ
    rm -f /tmp/claude-install.sh /tmp/claude-manager.sh
    # その他必要なクリーンアップがあればここに追加
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
    echo -e "${YELLOW}⚠️  外部スクリプトからClaude Codeをインストールします${NC}"
    echo "インストール元: https://claude.ai/install.sh"
    echo -n "続行しますか？ [y/N]: "
    read -r install_confirm
    
    if [ "$install_confirm" = "y" ] || [ "$install_confirm" = "Y" ]; then
        # 一時ファイルにダウンロードして内容を確認
        if secure_download "https://claude.ai/install.sh" "/tmp/claude-install.sh" "#!/"; then
            echo "インストールスクリプトを実行中..."
            sudo bash /tmp/claude-install.sh
            rm -f /tmp/claude-install.sh
        else
            echo -e "${YELLOW}Claude Codeのインストールはスキップされました${NC}"
        fi
    else
        echo -e "${YELLOW}Claude Codeのインストールはスキップされました${NC}"
    fi
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
    while true; do
        read -rp "GitHubで使用するメールアドレス: " email
        if validate_email "$email"; then
            break
        fi
        echo "有効なメールアドレスを入力してください。"
    done
    
    ssh-keygen -t ed25519 -C "$email" -N "" -f ~/.ssh/id_ed25519
    
    # SSH鍵ファイルの権限を確実に設定
    chmod 700 ~/.ssh
    chmod 600 ~/.ssh/id_ed25519
    chmod 644 ~/.ssh/id_ed25519.pub
    
    # GitHub認証済みの場合のみSSH鍵を追加
    if gh auth status >/dev/null 2>&1; then
        gh ssh-key add ~/.ssh/id_ed25519.pub --title "Claude Multi - $(hostname)"
        echo "✓ SSH鍵をGitHubに追加しました"
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

# claude-manager.shをセキュアにダウンロード
if secure_download \
    "https://raw.githubusercontent.com/ootakazuhiko/claude-multi/main/claude-manager.sh" \
    "/tmp/claude-manager.sh" \
    "#!/bin/bash"; then
    
    sudo mv /tmp/claude-manager.sh /opt/claude-shared/claude-manager.sh
    sudo chmod +x /opt/claude-shared/claude-manager.sh
else
    error_exit "claude-manager.shのダウンロードに失敗しました"
fi

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