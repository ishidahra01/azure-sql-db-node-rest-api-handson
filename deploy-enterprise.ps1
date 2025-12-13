# エンタープライズ構成デプロイスクリプト（PowerShell版）
# このスクリプトは、本格的なセキュア構成をAzureにデプロイします

param(
    [string]$ResourceGroup = "",
    [string]$Location = "japaneast"
)

$ErrorActionPreference = "Stop"

Write-Host "=========================================" -ForegroundColor Cyan
Write-Host "  Azure エンタープライズ構成デプロイ" -ForegroundColor Cyan
Write-Host "=========================================" -ForegroundColor Cyan
Write-Host ""

# パラメータファイルの確認
$ParamFile = "main-enterprise.parameters.json"
$TemplateFile = "main-enterprise.bicep"

if (-not (Test-Path $ParamFile)) {
    Write-Host "警告: パラメータファイルが見つかりません。" -ForegroundColor Yellow
    Write-Host "テンプレートからコピーします..."
    Copy-Item "main-enterprise.parameters.json.template" $ParamFile
    Write-Host ""
    Write-Host "重要: $ParamFile を編集して、以下の値を設定してください:" -ForegroundColor Red
    Write-Host "  - sqlAdminPassword: 強力なパスワード"
    Write-Host "  - apimPublisherEmail: 実際のメールアドレス"
    Write-Host "  - apimPublisherName: 組織名"
    Write-Host ""
    Read-Host "編集が完了したらEnterキーを押してください"
}

# Azure ログイン確認
Write-Host "Azure ログイン状態を確認中..."
try {
    $null = Get-AzContext -ErrorAction Stop
    Write-Host "✅ Azure にログイン済み" -ForegroundColor Green
    $Context = Get-AzContext
    Write-Host "サブスクリプション: $($Context.Subscription.Name)"
    Write-Host ""
    $confirm = Read-Host "このサブスクリプションでよろしいですか？ (yes/no)"
    if ($confirm -ne "yes") {
        Write-Host "デプロイを中止しました。"
        Write-Host "別のサブスクリプションを使用する場合は、以下のコマンドを実行してください:"
        Write-Host "  Set-AzContext -Subscription 'YOUR_SUBSCRIPTION_ID'"
        exit 0
    }
} catch {
    Write-Host "Azure にログインしていません。ログインを開始します..." -ForegroundColor Yellow
    Connect-AzAccount
}

Write-Host ""

# リソースグループ名の入力
if ([string]::IsNullOrEmpty($ResourceGroup)) {
    $ResourceGroup = Read-Host "リソースグループ名を入力してください (例: rg-handson-prod)"
}

if ([string]::IsNullOrEmpty($ResourceGroup)) {
    Write-Host "エラー: リソースグループ名が入力されませんでした。" -ForegroundColor Red
    exit 1
}

# リージョンの入力
if ([string]::IsNullOrEmpty($Location)) {
    $LocationInput = Read-Host "デプロイ先のリージョンを入力してください (デフォルト: japaneast)"
    if (-not [string]::IsNullOrEmpty($LocationInput)) {
        $Location = $LocationInput
    }
}

Write-Host ""
Write-Host "=========================================" -ForegroundColor Cyan
Write-Host "  デプロイ設定確認" -ForegroundColor Cyan
Write-Host "=========================================" -ForegroundColor Cyan
Write-Host "リソースグループ: $ResourceGroup"
Write-Host "リージョン: $Location"
Write-Host "テンプレート: $TemplateFile"
Write-Host "パラメータ: $ParamFile"
Write-Host ""
Write-Host "推定デプロイ時間: 60-90分" -ForegroundColor Yellow
Write-Host "推定月額コスト: `$4,000-5,000" -ForegroundColor Yellow
Write-Host ""
$startDeploy = Read-Host "デプロイを開始しますか？ (yes/no)"

if ($startDeploy -ne "yes") {
    Write-Host "デプロイを中止しました。"
    exit 0
}

Write-Host ""

# リソースグループの作成
Write-Host "=========================================" -ForegroundColor Cyan
Write-Host "  Step 1: リソースグループの作成" -ForegroundColor Cyan
Write-Host "=========================================" -ForegroundColor Cyan

$existingRg = Get-AzResourceGroup -Name $ResourceGroup -ErrorAction SilentlyContinue
if ($existingRg) {
    Write-Host "✅ リソースグループ '$ResourceGroup' は既に存在します" -ForegroundColor Green
} else {
    Write-Host "リソースグループを作成中..."
    New-AzResourceGroup -Name $ResourceGroup -Location $Location
    Write-Host "✅ リソースグループを作成しました" -ForegroundColor Green
}

Write-Host ""

# Bicep テンプレートの検証
Write-Host "=========================================" -ForegroundColor Cyan
Write-Host "  Step 2: テンプレートの検証" -ForegroundColor Cyan
Write-Host "=========================================" -ForegroundColor Cyan

Write-Host "Bicep 構文をチェック中..."
try {
    az bicep build --file $TemplateFile | Out-Null
    Write-Host "✅ Bicep 構文チェック成功" -ForegroundColor Green
} catch {
    Write-Host "❌ Bicep 構文エラーが見つかりました" -ForegroundColor Red
    az bicep build --file $TemplateFile
    exit 1
}

Write-Host ""
Write-Host "What-If 分析を実行中（デプロイせずに変更を確認）..."
Write-Host "※ この処理には数分かかる場合があります"
Write-Host ""

$whatIfResult = New-AzResourceGroupDeployment `
    -ResourceGroupName $ResourceGroup `
    -TemplateFile $TemplateFile `
    -TemplateParameterFile $ParamFile `
    -WhatIf

Write-Host ""
$confirmWhatif = Read-Host "上記の変更内容でよろしいですか？ (yes/no)"

if ($confirmWhatif -ne "yes") {
    Write-Host "デプロイを中止しました。"
    exit 0
}

Write-Host ""

# デプロイの実行
Write-Host "=========================================" -ForegroundColor Cyan
Write-Host "  Step 3: デプロイの実行" -ForegroundColor Cyan
Write-Host "=========================================" -ForegroundColor Cyan

$DeploymentName = "enterprise-$(Get-Date -Format 'yyyyMMdd-HHmmss')"

Write-Host "デプロイを開始します..."
Write-Host "デプロイ名: $DeploymentName"
Write-Host ""
Write-Host "⏳ デプロイには 60-90 分かかります。気長にお待ちください..." -ForegroundColor Yellow
Write-Host ""

$StartTime = Get-Date

try {
    $deployment = New-AzResourceGroupDeployment `
        -ResourceGroupName $ResourceGroup `
        -TemplateFile $TemplateFile `
        -TemplateParameterFile $ParamFile `
        -Name $DeploymentName `
        -Verbose
    
    $EndTime = Get-Date
    $Elapsed = ($EndTime - $StartTime).TotalMinutes
    
    Write-Host ""
    Write-Host "=========================================" -ForegroundColor Green
    Write-Host "  ✅ デプロイ成功！" -ForegroundColor Green
    Write-Host "=========================================" -ForegroundColor Green
    Write-Host "所要時間: $([math]::Round($Elapsed, 2)) 分"
    Write-Host ""
    
    # デプロイ結果の出力
    Write-Host "デプロイされたリソース:"
    Write-Host ""
    $deployment.Outputs | ConvertTo-Json -Depth 10
    
    Write-Host ""
    Write-Host "=========================================" -ForegroundColor Cyan
    Write-Host "  次のステップ" -ForegroundColor Cyan
    Write-Host "=========================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "1. SQL スクリプトの実行:"
    Write-Host "   - Azure Portal で SQL Database を開く"
    Write-Host "   - Query Editor で sql/HandsOnSetup.sql を実行"
    Write-Host ""
    Write-Host "2. Functions コードのデプロイ:"
    Write-Host "   func azure functionapp publish <functionAppName>"
    Write-Host ""
    Write-Host "3. 動作確認:"
    Write-Host "   詳細は ENTERPRISE_DEPLOYMENT.md を参照してください"
    Write-Host ""
} catch {
    Write-Host ""
    Write-Host "=========================================" -ForegroundColor Red
    Write-Host "  ❌ デプロイ失敗" -ForegroundColor Red
    Write-Host "=========================================" -ForegroundColor Red
    Write-Host ""
    Write-Host "エラー: $_" -ForegroundColor Red
    Write-Host ""
    Write-Host "エラーログを確認してください:"
    Write-Host "  Get-AzResourceGroupDeployment -ResourceGroupName $ResourceGroup -Name $DeploymentName"
    Write-Host ""
    exit 1
}
