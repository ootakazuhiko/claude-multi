# setup-wsl.ps1
# Claude専用WSL環境のセットアップスクリプト

param(
    [switch]$Force
)

$ErrorActionPreference = "Stop"

# WSLディストリビューション存在確認関数
function Test-WSLDistribution {
    param([string]$DistroName)
    $distros = wsl --list --quiet 2>$null
    if ($distros) {
        return $distros | Where-Object { $_ -eq $DistroName }
    }
    return $false
}

Write-Host "Claude-Multi WSL環境セットアップ" -ForegroundColor Cyan
Write-Host "================================" -ForegroundColor Cyan
Write-Host ""

# 既存のClaude-Multi環境をチェック
$existingDistros = Test-WSLDistribution "Claude-Multi"

if ($existingDistros -and -not $Force) {
    Write-Host "⚠️  Claude-Multi環境は既に存在します" -ForegroundColor Yellow
    Write-Host "上書きする場合は -Force オプションを使用してください"
    exit 1
}

if ($existingDistros -and $Force) {
    Write-Host "既存のClaude-Multi環境を削除中..." -ForegroundColor Yellow
    wsl --unregister Claude-Multi
}

# Ubuntu-22.04が既に存在するか確認
$ubuntuExists = Test-WSLDistribution "Ubuntu-22.04"

if (-not $ubuntuExists) {
    Write-Host "📦 Ubuntu 22.04をインストール中..." -ForegroundColor Green
    
    try {
        wsl --install -d Ubuntu-22.04 --no-launch
    } catch {
        Write-Host "❌ Ubuntu 22.04のインストールに失敗しました: $_" -ForegroundColor Red
        exit 1
    }
    
    Write-Host "⏳ インストール完了を待機中..." -ForegroundColor Yellow
    
    # インストール完了を待機（最大5分）
    $maxWaitTime = 300 # 5分
    $waitTime = 0
    $waitInterval = 10
    
    do {
        Start-Sleep -Seconds $waitInterval
        $waitTime += $waitInterval
        $ubuntuInstalled = Test-WSLDistribution "Ubuntu-22.04"
        
        if ($ubuntuInstalled) {
            Write-Host "✅ Ubuntu 22.04のインストールが完了しました" -ForegroundColor Green
            break
        }
        
        if ($waitTime -ge $maxWaitTime) {
            Write-Host "❌ Ubuntu 22.04のインストールがタイムアウトしました" -ForegroundColor Red
            Write-Host "手動でインストールを確認してください: wsl --list" -ForegroundColor Yellow
            exit 1
        }
        
        Write-Host "⏳ 待機中... ($waitTime/$maxWaitTime 秒)" -ForegroundColor Yellow
    } while ($true)
    
    Write-Host "📤 エクスポート中..." -ForegroundColor Green
    try {
        wsl --export Ubuntu-22.04 "$env:TEMP\ubuntu-base.tar"
        if (-not (Test-Path "$env:TEMP\ubuntu-base.tar")) {
            throw "エクスポートファイルが作成されませんでした"
        }
    } catch {
        Write-Host "❌ Ubuntu 22.04のエクスポートに失敗しました: $_" -ForegroundColor Red
        exit 1
    }
    
    $removeOriginal = $true
} else {
    Write-Host "✅ Ubuntu-22.04は既に存在します" -ForegroundColor Green
    Write-Host "📤 エクスポート中..." -ForegroundColor Green
    try {
        wsl --export Ubuntu-22.04 "$env:TEMP\ubuntu-base.tar"
        if (-not (Test-Path "$env:TEMP\ubuntu-base.tar")) {
            throw "エクスポートファイルが作成されませんでした"
        }
    } catch {
        Write-Host "❌ Ubuntu 22.04のエクスポートに失敗しました: $_" -ForegroundColor Red
        exit 1
    }
    
    $removeOriginal = $false
}

Write-Host "📥 Claude-Multiとしてインポート中..." -ForegroundColor Green
$installPath = "$env:USERPROFILE\WSL\Claude-Multi"
New-Item -ItemType Directory -Path $installPath -Force | Out-Null

try {
    wsl --import Claude-Multi $installPath "$env:TEMP\ubuntu-base.tar"
    
    # インポートが成功したか確認
    if (-not (Test-WSLDistribution "Claude-Multi")) {
        throw "Claude-Multi環境のインポートに失敗しました"
    }
    Write-Host "✅ Claude-Multi環境のインポートが完了しました" -ForegroundColor Green
} catch {
    Write-Host "❌ Claude-Multi環境のインポートに失敗しました: $_" -ForegroundColor Red
    
    # クリーンアップして終了
    Write-Host "🧹 エラー時のクリーンアップ中..." -ForegroundColor Yellow
    if (Test-Path "$env:TEMP\ubuntu-base.tar") {
        Remove-Item "$env:TEMP\ubuntu-base.tar" -ErrorAction SilentlyContinue
    }
    exit 1
}

Write-Host "🧹 クリーンアップ中..." -ForegroundColor Green
if ($removeOriginal) {
    # Ubuntu-22.04が存在する場合のみ削除を試行
    if (Test-WSLDistribution "Ubuntu-22.04") {
        wsl --unregister Ubuntu-22.04
        Write-Host "  ✓ Ubuntu-22.04を削除しました" -ForegroundColor Gray
    }
} else {
    Write-Host "  ℹ️  元のUbuntu-22.04は保持されます" -ForegroundColor Gray
}

# ubuntu-base.tarファイルが存在する場合のみ削除
if (Test-Path "$env:TEMP\ubuntu-base.tar") {
    Remove-Item "$env:TEMP\ubuntu-base.tar"
    Write-Host "  ✓ 一時ファイルを削除しました" -ForegroundColor Gray
}

Write-Host "" 
Write-Host "✅ セットアップ完了！" -ForegroundColor Green
Write-Host ""
Write-Host "次のコマンドでClaude-Multi環境に入ってください："
Write-Host "  wsl -d Claude-Multi" -ForegroundColor Cyan
Write-Host ""
Write-Host "その後、以下を実行してください："
Write-Host "  curl -fsSL https://raw.githubusercontent.com/ootakazuhiko/claude-multi/main/quick-setup.sh | bash" -ForegroundColor Cyan