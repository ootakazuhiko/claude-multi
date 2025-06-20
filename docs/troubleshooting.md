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

#### WSLセットアップエラー

##### 「指定された名前のディストリビューションはありません」エラー

```
指定された名前のディストリビューションはありません。
エラー コード: Wsl/Service/WSL_E_DISTRO_NOT_FOUND
```

このエラーは `setup-wsl.ps1` 実行時にUbuntu 22.04のインストールが失敗した場合に発生します。

**解決方法：**
1. WSL機能が有効になっているか確認
2. 管理者権限でPowerShellを実行
3. インターネット接続を確認
4. 時間を置いてから再実行

```powershell
# WSL機能確認
dism.exe /online /get-featureinfo /featurename:Microsoft-Windows-Subsystem-Linux

# 手動でUbuntu-22.04をインストール
wsl --install -d Ubuntu-22.04
```

##### 「指定されたファイルが見つかりません」エラー

```
指定されたファイルが見つかりません。
エラー コード: Wsl/ERROR_FILE_NOT_FOUND
```

このエラーは一時ファイル（ubuntu-base.tar）の作成に失敗した場合に発生します。スクリプトは自動的にリトライと検証を行うようになりました。

#### SSH鍵の追加で "admin:public_key" スコープエラー

GitHub CLI でSSH鍵を追加する際にスコープエラーが発生する場合：

```bash
# GitHub認証を更新（admin:public_keyスコープを追加）
gh auth refresh -h github.com -s admin:public_key

# SSH鍵を追加
gh ssh-key add ~/.ssh/id_ed25519.pub --title "Claude Multi - $(hostname)"
```

このエラーは初回の `gh auth login` 時に必要なスコープが含まれていない場合に発生します。

#### SSH鍵作成時のメールアドレス入力エラー

SSH鍵作成時にメールアドレスの入力でエラーが繰り返し発生する場合：

**よくある入力ミスと解決方法：**

| 入力例 | エラーの原因 | 正しい形式 |
|--------|-------------|-----------|
| `user` | @記号がない | `user@example.com` |
| `user@` | ドメイン名がない | `user@gmail.com` |
| `user@domain` | 拡張子がない | `user@domain.com` |
| `user@@domain.com` | @記号が重複 | `user@domain.com` |
| `user@domain.` | 拡張子が不完全 | `user@domain.com` |

**推奨事項：**
- GitHubアカウントに登録しているメールアドレスを使用
- 入力後にスペースや改行が含まれていないか確認
- コピー＆ペーストを活用して入力ミスを防ぐ

**手動でSSH鍵を作成する場合：**
```bash
ssh-keygen -t ed25519 -C "your-email@example.com" -N "" -f ~/.ssh/id_ed25519
```

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

## Claude-Multi環境関連

### Claude-Multi環境が見つからない

```powershell
# 環境一覧を確認
wsl --list --verbose

# Claude-Multi環境を作成していない場合は、READMEの手順に従って作成
# https://github.com/ootakazuhiko/claude-multi#推奨claude専用wsl環境の作成
```

### 間違えて通常のUbuntu環境で実行してしまった

通常のUbuntu環境でセットアップしてしまった場合でも動作しますが、以下の方法でClaude-Multi環境に移行できます：

1. 現在の環境をバックアップ
2. Claude-Multi環境を新規作成
3. Claude-Multi環境でセットアップを実行

### WSL環境の判別

現在どの環境にいるか確認：

```bash
echo $WSL_DISTRO_NAME
```

プロンプトで環境を分かりやすくする：

```bash
# Claude-Multi環境の ~/.bashrc に追加
export PS1="\[\033[01;35m\][Claude-Multi]\[\033[00m\] \[\033[01;32m\]\u@\h\[\033[00m\]:\[\033[01;34m\]\w\[\033[00m\]\$ "
```

### Claude-Multi環境のリセット

問題が解決しない場合、環境を完全にリセット：

```powershell
# バックアップ（必要な場合）
wsl --export Claude-Multi claude-backup.tar

# 環境削除
wsl --unregister Claude-Multi

# 再作成
wsl --import Claude-Multi "$env:USERPROFILE\WSL\Claude-Multi" ubuntu-base.tar
```

## サポート

問題が解決しない場合は、以下の情報と共にIssueを作成してください：

1. `claude-manager health <project>` の出力
2. `claude-manager logs <project>` の関連部分
3. エラーメッセージの全文