# setup-wsl.ps1
# Claude専用WSL環境のセットアップスクリプト

param(
    [switch]$Force
)

$ErrorActionPreference = "Stop"

Write-Host "Claude-Multi WSL環境セットアップ" -ForegroundColor Cyan
Write-Host "================================" -ForegroundColor Cyan
Write-Host ""

# 既存のClaude-Multi環境をチェック
$existingDistros = wsl --list --quiet | Where-Object { $_ -eq "Claude-Multi" }

if ($existingDistros -and -not $Force) {
    Write-Host "⚠️  Claude-Multi環境は既に存在します" -ForegroundColor Yellow
    Write-Host "上書きする場合は -Force オプションを使用してください"
    exit 1
}

if ($existingDistros -and $Force) {
    Write-Host "既存のClaude-Multi環境を削除中..." -ForegroundColor Yellow
    wsl --unregister Claude-Multi
}

Write-Host "📦 Ubuntu 22.04をインストール中..." -ForegroundColor Green
wsl --install -d Ubuntu-22.04 --no-launch

Write-Host "⏳ インストール完了を待機中..." -ForegroundColor Yellow
Start-Sleep -Seconds 10

Write-Host "📤 エクスポート中..." -ForegroundColor Green
wsl --export Ubuntu-22.04 "$env:TEMP\ubuntu-base.tar"

Write-Host "📥 Claude-Multiとしてインポート中..." -ForegroundColor Green
$installPath = "$env:USERPROFILE\WSL\Claude-Multi"
New-Item -ItemType Directory -Path $installPath -Force | Out-Null
wsl --import Claude-Multi $installPath "$env:TEMP\ubuntu-base.tar"

Write-Host "🧹 クリーンアップ中..." -ForegroundColor Green
wsl --unregister Ubuntu-22.04
Remove-Item "$env:TEMP\ubuntu-base.tar"

Write-Host "" 
Write-Host "✅ セットアップ完了！" -ForegroundColor Green
Write-Host ""
Write-Host "次のコマンドでClaude-Multi環境に入ってください："
Write-Host "  wsl -d Claude-Multi" -ForegroundColor Cyan
Write-Host ""
Write-Host "その後、以下を実行してください："
Write-Host "  curl -fsSL https://raw.githubusercontent.com/ootakazuhiko/claude-multi/main/quick-setup.sh | bash" -ForegroundColor Cyan