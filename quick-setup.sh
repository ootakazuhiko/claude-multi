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

# 対話環境チェック関数（必要な時のみ）
check_interactive() {
    if [ ! -t 0 ] || [ ! -t 1 ]; then
        echo -e "${RED}エラー: この操作には対話的な環境が必要です。ターミナルから実行してください${NC}" >&2
        return 1
    fi
    return 0
}

# 入力値検証関数
validate_email() {
    local email="$1"
    if [ -z "$email" ]; then
        echo -e "${RED}エラー: メールアドレスが入力されていません (例: user@example.com)${NC}" >&2
        return 1
    fi
    
    # 基本的なメールアドレス形式チェック
    if ! [[ "$email" =~ ^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$ ]]; then
        echo -e "${RED}❌ エラー: 有効なメールアドレス形式ではありません (正しい形式: user@example.com)${NC}" >&2
        
        # より具体的なヒントを提供（ワンライナー形式）
        if [[ ! "$email" =~ @ ]]; then
            echo -e "${YELLOW}💡 ヒント: '@'記号が必要です${NC}" >&2
        elif [[ "$email" =~ @.*@.* ]]; then
            echo -e "${YELLOW}💡 ヒント: '@'記号は1つだけ使用してください${NC}" >&2
        elif [[ "$email" =~ @$ ]]; then
            echo -e "${YELLOW}💡 ヒント: '@'の後にドメイン名が必要です (例: gmail.com)${NC}" >&2
        elif [[ ! "$email" =~ \. ]]; then
            echo -e "${YELLOW}💡 ヒント: ドメインには'.'が必要です (例: example.com)${NC}" >&2
        elif [[ "$email" =~ \.$ ]]; then
            echo -e "${YELLOW}💡 ヒント: ドメインの拡張子が必要です (例: .com, .org)${NC}" >&2
        fi
        
        echo -e "${YELLOW}💡 推奨: GitHubアカウント登録済みメールアドレスをコピペしてください${NC}" >&2
        
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
    echo "Claude専用環境（Claude-Multi）の使用を推奨します。このまま続行しますか？ [y/N]: "
    if ! check_interactive; then
        echo "非対話環境のため、Claude-Multi環境での実行を強く推奨します"
        echo "Claude-Multi環境の作成方法: https://github.com/ootakazuhiko/claude-multi#推奨claude専用wsl環境の作成"
        echo "このまま続行します..."
    else
        read -r confirm
        if [ "$confirm" != "y" ] && [ "$confirm" != "Y" ]; then
            echo "Claude-Multi環境の作成方法: https://github.com/ootakazuhiko/claude-multi#推奨claude専用wsl環境の作成"
            exit 0
        fi
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
    
    if ! check_interactive; then
        echo "非対話環境のため、Claude Codeのインストールをスキップします"
        echo -e "${YELLOW}Claude Codeのインストールはスキップされました${NC}"
        echo "後で手動でインストールしてください: curl -fsSL https://claude.ai/install.sh | sudo bash"
    else
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
    # 対話環境チェック
    if ! check_interactive; then
        echo -e "${YELLOW}非対話環境が検出されました。SSH鍵の生成をスキップします${NC}"
        echo "後で手動でSSH鍵を作成してください:"
        echo "  ssh-keygen -t ed25519 -C \"your-email@example.com\" -N \"\" -f ~/.ssh/id_ed25519"
        echo "  gh ssh-key add ~/.ssh/id_ed25519.pub --title \"Claude Multi - \$(hostname)\""
    else
    
    echo "GitHubで使用するメールアドレスを入力してください。"
    echo -e "${YELLOW}注意: GitHubアカウントに登録されているメールアドレスを使用することを推奨します${NC}"
    echo ""
    
    # 入力試行回数制限とタイムアウト保護
    attempt_count=0
    max_attempts=5
    last_input=""
    
    while true; do
        # 最大試行回数チェック
        if [ $attempt_count -ge $max_attempts ]; then
            echo -e "${RED}エラー: 最大試行回数(${max_attempts}回)に達しました。手動でSSH鍵を作成してください: ssh-keygen -t ed25519 -C \"your-email@example.com\" -N \"\" -f ~/.ssh/id_ed25519${NC}" >&2
            exit 1
        fi
        
        # 試行回数表示（初回以外）
        if [ $attempt_count -gt 0 ]; then
            echo -e "${YELLOW}--- 再入力をお願いします (試行 $((attempt_count + 1))/${max_attempts}) ---${NC}" && [ -n "$last_input" ] && echo -e "${YELLOW}前回の入力: ${NC}「${last_input}」"
        fi
        
        # 入力プロンプト表示
        echo -n "GitHubで使用するメールアドレス: "
        
        # タイムアウト付きで入力を読み取り
        if email=$(timeout 30 bash -c "read -r input && echo \"\$input\"" 2>&1); then
            # 前後の空白を除去
            email=$(echo "$email" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
            last_input="$email"
            
            # 空白文字や改行の混入をチェック
            if [[ "$email" =~ [[:space:]] ]]; then
                echo -e "${YELLOW}⚠️  メールアドレスにスペースや改行が含まれています: 「${email}」${NC}"
            elif validate_email "$email"; then
                echo -e "${GREEN}✓ 有効なメールアドレスです: $email${NC}"
                break
            fi
            # 残り試行回数を表示
            remaining_attempts=$((max_attempts - attempt_count - 1))
            if [ $remaining_attempts -gt 0 ]; then
                echo -e "${YELLOW}残り試行回数: ${remaining_attempts}回${NC}"
            fi
        else
            read_exit_code=$?
            if [ $read_exit_code -eq 124 ]; then
                echo -e "${RED}エラー: 入力タイムアウト（30秒）${NC}" >&2
            else
                echo -e "${RED}エラー: 入力の読み取りに失敗しました（終了コード: $read_exit_code）${NC}" >&2
            fi
            echo "対話環境で再実行するか、手動でSSH鍵を作成してください: ssh-keygen -t ed25519 -C \"your-email@example.com\" -N \"\" -f ~/.ssh/id_ed25519"
            exit 1
        fi
        
        ((attempt_count++))
    done
    
    ssh-keygen -t ed25519 -C "$email" -N "" -f ~/.ssh/id_ed25519
    
    # SSH鍵ファイルの権限を確実に設定
    chmod 700 ~/.ssh
    chmod 600 ~/.ssh/id_ed25519
    chmod 644 ~/.ssh/id_ed25519.pub
    
    # GitHub認証済みの場合のみSSH鍵を追加
    if gh auth status >/dev/null 2>&1; then
        # SSH鍵追加を試行し、スコープエラーを検出
        ssh_key_output=$(gh ssh-key add ~/.ssh/id_ed25519.pub --title "Claude Multi - $(hostname)" 2>&1)
        ssh_key_exit_code=$?
        
        if [ $ssh_key_exit_code -eq 0 ]; then
            echo "✓ SSH鍵をGitHubに追加しました"
        elif echo "$ssh_key_output" | grep -q "admin:public_key"; then
            echo -e "${YELLOW}⚠️  SSH鍵の追加にはadmin:public_keyスコープが必要です。認証更新: gh auth refresh -h github.com -s admin:public_key${NC}"
        else
            echo -e "${YELLOW}⚠️  SSH鍵の追加に失敗しました。手動で追加してください: gh ssh-key add ~/.ssh/id_ed25519.pub --title \"Claude Multi - $(hostname)\"${NC}"
        fi
    else
        echo "✓ SSH鍵を作成しました"
        echo -e "${YELLOW}※ GitHub認証後、以下のコマンドでSSH鍵を追加してください：${NC}"
        echo "  gh ssh-key add ~/.ssh/id_ed25519.pub --title \"Claude Multi - $(hostname)\""
    fi
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

echo -e "${GREEN}✅ セットアップ完了！次の手順: 1) WSL再起動 (exit → wsl --shutdown → wsl -d Claude-Multi) 2) プロジェクト作成 (claude-manager quickstart myproject)${NC}"