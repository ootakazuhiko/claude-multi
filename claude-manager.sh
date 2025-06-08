#!/bin/bash
set -e

# 色付き出力
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

usage() {
    cat << EOF
Claude Multi - 複数Claude Code環境管理ツール

使用方法: claude-manager <command> [options]

🚀 クイックコマンド:
  quickstart <n>    プロジェクト作成〜起動まで一発実行
  
📁 プロジェクト管理:
  create <n>        プロジェクト作成
  delete <n>        プロジェクト削除
  list                 全プロジェクト一覧
  
🔧 サービス制御:
  start <n>         サービス開始
  stop <n>          サービス停止
  restart <n>       サービス再起動
  start-all            全プロジェクト起動
  stop-all             全プロジェクト停止
  
📊 状態確認:
  status <n>        プロジェクト状態
  health <n>        ヘルスチェック
  logs <n>          ログ表示（Ctrl+Cで終了）
  
例:
  claude-manager quickstart frontend
  claude-manager list
  claude-manager start-all
EOF
}

# エラーチェック関数
check_project_exists() {
    local name=$1
    if ! id "claude-$name" &>/dev/null; then
        echo -e "${RED}エラー: プロジェクト '$name' が存在しません${NC}"
        echo "利用可能なプロジェクト:"
        list_projects_simple
        exit 1
    fi
}

# 次の利用可能なUID取得
get_next_uid() {
    local uid=2001
    while getent passwd | grep -q ":${uid}:"; do
        ((uid++))
    done
    echo $uid
}

# シンプルなプロジェクト一覧（エラー時用）
list_projects_simple() {
    for user in $(getent passwd | grep "^claude-" | cut -d: -f1 | sort); do
        echo "  - ${user#claude-}"
    done
}

# プロジェクト作成
create_project() {
    local name=$1
    
    if [ -z "$name" ]; then
        echo -e "${RED}エラー: プロジェクト名を指定してください${NC}"
        exit 1
    fi
    
    if id "claude-$name" &>/dev/null; then
        echo -e "${YELLOW}プロジェクト '$name' は既に存在します${NC}"
        return 1
    fi
    
    local uid=$(get_next_uid)
    
    echo "📦 プロジェクト '$name' を作成中..."
    
    # ユーザー作成
    useradd -m -u $uid -s /bin/bash claude-$name
    loginctl enable-linger claude-$name
    
    # ディレクトリ作成
    sudo -u claude-$name mkdir -p /home/claude-$name/workspace
    
    # Podman設定
    sudo -u claude-$name podman system migrate >/dev/null 2>&1
    sudo -u claude-$name systemctl --user enable podman.socket >/dev/null 2>&1
    
    # 環境設定
    cat >> /home/claude-$name/.bashrc <<'BASHRC_EOF'
export DOCKER_HOST=unix:///run/user/$(id -u)/podman/podman.sock
alias docker=podman
alias docker-compose='podman-compose'
export PS1='\[\033[01;32m\]claude-${USER#claude-}\[\033[00m\]:\[\033[01;34m\]\w\[\033[00m\]\$ '
BASHRC_EOF
    
    # CLAUDE.md作成
    sudo -u claude-$name tee /home/claude-$name/workspace/CLAUDE.md >/dev/null <<CLAUDE_EOF
# Project: $name

このプロジェクトはClaude Multi環境で管理されています。

## 環境情報

- Podman (rootless) で実行環境を管理
- \`docker\` コマンドは \`podman\` にエイリアスされています
- ポート3000-3010が利用可能です

## 基本コマンド

\`\`\`bash
# コンテナ実行例
docker run -d -p 3000:3000 --name myapp myimage

# コンテナ確認
docker ps

# ログ確認
docker logs myapp
\`\`\`
CLAUDE_EOF
    
    # Claude Codeの存在確認
    local claude_path=""
    if command -v claude >/dev/null 2>&1; then
        claude_path=$(command -v claude)
        echo "✓ Claude Code が見つかりました: $claude_path"
    else
        echo -e "${YELLOW}⚠️  Claude Code が見つかりません。プレースホルダーサービスを作成します。${NC}"
        claude_path="/bin/echo"
    fi
    
    # systemdサービス作成
    if [ "$claude_path" = "/bin/echo" ]; then
        # Claude Codeが利用できない場合のプレースホルダーサービス
        cat > /etc/systemd/system/claude-code@$name.service <<SERVICE_EOF
[Unit]
Description=Claude Code - $name (Placeholder)
After=network.target

[Service]
Type=oneshot
User=claude-$name
WorkingDirectory=/home/claude-$name/workspace
Environment="DOCKER_HOST=unix:///run/user/$uid/podman/podman.sock"
Environment="CLAUDE_PROJECT=$name"
ExecStartPre=/bin/bash -c 'sudo -u claude-$name systemctl --user start podman.socket'
ExecStart=/bin/echo "Claude Code is not available. Project $name workspace is ready for manual development."
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
SERVICE_EOF
    else
        # Claude Codeが利用可能な場合の通常サービス
        cat > /etc/systemd/system/claude-code@$name.service <<SERVICE_EOF
[Unit]
Description=Claude Code - $name
After=network.target

[Service]
Type=simple
User=claude-$name
WorkingDirectory=/home/claude-$name/workspace
Environment="DOCKER_HOST=unix:///run/user/$uid/podman/podman.sock"
Environment="CLAUDE_PROJECT=$name"
Environment="PATH=$PATH"
ExecStartPre=/bin/bash -c 'sudo -u claude-$name systemctl --user start podman.socket'
ExecStart=$claude_path code
Restart=on-failure
RestartSec=10
MemoryLimit=4G
CPUQuota=200%

[Install]
WantedBy=multi-user.target
SERVICE_EOF
    fi
    
    systemctl daemon-reload
    systemctl enable claude-code@$name >/dev/null 2>&1
    
    echo -e "${GREEN}✅ プロジェクト作成完了${NC}"
}

# GitHub設定コピー
setup_git() {
    local name=$1
    local source_user=${SUDO_USER:-$(logname 2>/dev/null || whoami)}
    
    echo "🔧 GitHub設定をコピー中..."
    
    # SSH鍵コピー
    if [ -d "/home/$source_user/.ssh" ]; then
        cp -r /home/$source_user/.ssh /home/claude-$name/
        chown -R claude-$name:claude-$name /home/claude-$name/.ssh
        chmod 700 /home/claude-$name/.ssh
        chmod 600 /home/claude-$name/.ssh/* 2>/dev/null || true
    fi
    
    # GitHub CLI設定コピー
    if [ -d "/home/$source_user/.config/gh" ]; then
        mkdir -p /home/claude-$name/.config
        cp -r /home/$source_user/.config/gh /home/claude-$name/.config/
        chown -R claude-$name:claude-$name /home/claude-$name/.config
    fi
    
    # Git設定コピー
    if [ -f "/home/$source_user/.gitconfig" ]; then
        cp /home/$source_user/.gitconfig /home/claude-$name/
        chown claude-$name:claude-$name /home/claude-$name/.gitconfig
    fi
    
    echo -e "${GREEN}✅ GitHub設定完了${NC}"
}

# クイックスタート
quickstart() {
    local name=$1
    
    if [ -z "$name" ]; then
        echo -e "${RED}エラー: プロジェクト名を指定してください${NC}"
        echo "例: claude-manager quickstart myproject"
        exit 1
    fi
    
    echo "🚀 Claude Code環境 '$name' をセットアップ中..."
    echo ""
    
    # プロジェクト作成
    if ! create_project $name; then
        return 1
    fi
    
    # Git設定
    setup_git $name
    
    # サービス起動
    systemctl start claude-code@$name
    
    # 少し待つ
    echo -n "起動中"
    for i in {1..5}; do
        echo -n "."
        sleep 1
    done
    echo ""
    
    # 起動確認
    if systemctl is-active --quiet claude-code@$name; then
        echo ""
        # Claude Codeの利用可能性を確認してメッセージを調整
        if command -v claude >/dev/null 2>&1; then
            echo -e "${GREEN}✨ セットアップ完了！${NC}"
            echo ""
            echo "📂 VS Codeで開く:"
            echo "  code --remote wsl+Ubuntu /home/claude-$name/workspace"
            echo ""
            echo "📋 プロジェクトに入る:"
            echo "  sudo -u claude-$name -i bash"
            echo ""
            echo "🔍 状態確認:"
            echo "  claude-manager health $name"
        else
            echo -e "${GREEN}✨ プロジェクト環境セットアップ完了！${NC}"
            echo ""
            echo -e "${YELLOW}📝 Claude Codeは利用できませんが、開発環境は準備完了です。${NC}"
            echo ""
            echo "📂 VS Codeで開く:"
            echo "  code --remote wsl+Ubuntu /home/claude-$name/workspace"
            echo ""
            echo "📋 プロジェクトに入る:"
            echo "  sudo -u claude-$name -i bash"
            echo ""
            echo "💡 ヒント:"
            echo "  - Podmanでコンテナを実行できます (dockerコマンドでアクセス可能)"
            echo "  - ポート3000-3010が利用可能です"
            echo ""
            echo "🔍 状態確認:"
            echo "  claude-manager health $name"
        fi
    else
        echo ""
        echo -e "${RED}⚠️  起動に失敗しました${NC}"
        echo "ログを確認してください:"
        echo "  claude-manager logs $name"
    fi
}

# プロジェクト一覧
list_projects() {
    local projects_found=false
    
    echo "📋 Claude Codeプロジェクト一覧"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    printf "%-15s %-12s %-25s\n" "プロジェクト" "状態" "ワークスペース"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    
    for user in $(getent passwd | grep "^claude-" | cut -d: -f1 | sort); do
        projects_found=true
        local name=${user#claude-}
        local status=$(systemctl is-active claude-code@$name 2>/dev/null)
        local workspace="/home/$user/workspace"
        
        if [ "$status" = "active" ]; then
            # サービスの説明からプレースホルダーかどうか判断
            local service_desc=$(systemctl show claude-code@$name -p Description --value 2>/dev/null)
            if echo "$service_desc" | grep -q "Placeholder"; then
                status="${YELLOW}● 準備完了${NC}"
            else
                status="${GREEN}● 動作中${NC}"
            fi
        else
            status="${RED}● 停止${NC}"
        fi
        
        printf "%-15s %-20b %-25s\n" "$name" "$status" "$workspace"
    done
    
    if [ "$projects_found" = false ]; then
        echo "プロジェクトがありません"
        echo ""
        echo "作成するには: claude-manager quickstart <n>"
    fi
}

# ヘルスチェック
health_check() {
    local name=$1
    check_project_exists $name
    
    echo "🏥 ヘルスチェック: $name"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    
    # サービス状態
    if systemctl is-active --quiet claude-code@$name; then
        # サービスの説明からプレースホルダーかどうか判断
        local service_desc=$(systemctl show claude-code@$name -p Description --value)
        if echo "$service_desc" | grep -q "Placeholder"; then
            echo -e "Claude Code:      ${YELLOW}● プレースホルダー (Claude Code未インストール)${NC}"
        else
            echo -e "Claude Code:      ${GREEN}● 正常${NC}"
        fi
    else
        echo -e "Claude Code:      ${RED}● 異常${NC}"
        echo ""
        echo "起動するには: claude-manager start $name"
        return 1
    fi
    
    # Podman動作確認
    if sudo -u claude-$name podman info >/dev/null 2>&1; then
        echo -e "Podman:           ${GREEN}● 正常${NC}"
    else
        echo -e "Podman:           ${RED}● 異常${NC}"
    fi
    
    # コンテナ数
    local containers=$(sudo -u claude-$name podman ps -q 2>/dev/null | wc -l)
    echo "実行中コンテナ:   $containers"
    
    # ディスク使用量
    local disk_usage=$(du -sh /home/claude-$name/workspace 2>/dev/null | cut -f1)
    echo "ディスク使用量:   $disk_usage"
}

# 一括操作
start_all() {
    echo "🚀 全プロジェクトを起動中..."
    local count=0
    
    for user in $(getent passwd | grep "^claude-" | cut -d: -f1); do
        local name=${user#claude-}
        systemctl start claude-code@$name 2>/dev/null
        echo "  ✓ $name"
        ((count++))
    done
    
    echo ""
    echo -e "${GREEN}✅ $count プロジェクトを起動しました${NC}"
}

stop_all() {
    echo "🛑 全プロジェクトを停止中..."
    local count=0
    
    for user in $(getent passwd | grep "^claude-" | cut -d: -f1); do
        local name=${user#claude-}
        systemctl stop claude-code@$name 2>/dev/null
        echo "  ✓ $name"
        ((count++))
    done
    
    echo ""
    echo -e "${GREEN}✅ $count プロジェクトを停止しました${NC}"
}

# プロジェクト削除
delete_project() {
    local name=$1
    check_project_exists $name
    
    echo -e "${YELLOW}⚠️  警告: この操作は取り消せません${NC}"
    echo "プロジェクト '$name' の以下が削除されます:"
    echo "  - /home/claude-$name 以下のすべてのファイル"
    echo "  - 実行中のコンテナとイメージ"
    echo ""
    echo -n "本当に削除しますか？ [yes/N]: "
    read -r confirm
    
    if [ "$confirm" != "yes" ]; then
        echo "キャンセルしました"
        return
    fi
    
    echo "削除中..."
    
    # サービス停止・無効化
    systemctl stop claude-code@$name 2>/dev/null || true
    systemctl disable claude-code@$name 2>/dev/null || true
    rm -f /etc/systemd/system/claude-code@$name.service
    
    # Podmanクリーンアップ（ユーザー権限で）
    sudo -u claude-$name podman system prune -af >/dev/null 2>&1 || true
    
    # ユーザー削除
    userdel -r claude-$name 2>/dev/null || true
    
    systemctl daemon-reload
    
    echo -e "${GREEN}✅ プロジェクト '$name' を削除しました${NC}"
}

# メイン処理
case "${1:-}" in
    quickstart)
        quickstart "$2"
        ;;
    create)
        create_project "$2"
        ;;
    setup-git)
        check_project_exists "$2"
        setup_git "$2"
        ;;
    start)
        check_project_exists "$2"
        systemctl start claude-code@$2
        echo -e "${GREEN}✅ 起動完了${NC}"
        ;;
    stop)
        check_project_exists "$2"
        systemctl stop claude-code@$2
        echo -e "${GREEN}✅ 停止完了${NC}"
        ;;
    restart)
        check_project_exists "$2"
        systemctl restart claude-code@$2
        echo -e "${GREEN}✅ 再起動完了${NC}"
        ;;
    status)
        check_project_exists "$2"
        systemctl status claude-code@$2 --no-pager
        ;;
    logs)
        check_project_exists "$2"
        echo "ログを表示中... (Ctrl+C で終了)"
        journalctl -u claude-code@$2 -f
        ;;
    list)
        list_projects
        ;;
    health)
        health_check "$2"
        ;;
    start-all)
        start_all
        ;;
    stop-all)
        stop_all
        ;;
    delete)
        delete_project "$2"
        ;;
    *)
        usage
        ;;
esac