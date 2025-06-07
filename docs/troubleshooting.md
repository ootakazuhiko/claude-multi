# トラブルシューティングガイド

## よくある問題と解決方法

### セットアップ関連

#### systemdが有効にならない

```bash
# WSL設定確認
cat /etc/wsl.conf

# 手動で有効化
sudo tee /etc/wsl.conf <<EOF
[boot]
systemd=true
EOF

# WSL再起動（PowerShellで）
wsl --shutdown
```

#### Claude Codeがインストールできない

Claude Codeは現在限定アクセスです。インストールがスキップされても、他の機能は正常に動作します。

### プロジェクト関連

#### サービスが起動しない

```bash
# エラー詳細確認
claude-manager logs myproject

# Podmanソケット再起動
sudo -u claude-myproject systemctl --user restart podman.socket

# サービス再起動
claude-manager restart myproject
```

#### Podmanエラー: "cannot find newuidmap"

```bash
# uidmapインストール
sudo apt install -y uidmap

# 設定確認
sudo -u claude-myproject podman info
```

### ネットワーク関連

#### ポートにアクセスできない

```bash
# 使用中のポート確認
ss -tlnp | grep :3000

# ファイアウォール確認（WSL2では通常不要）
sudo iptables -L
```

## サポート

問題が解決しない場合は、以下の情報と共にIssueを作成してください：

1. `claude-manager health <project>` の出力
2. `claude-manager logs <project>` の関連部分
3. エラーメッセージの全文