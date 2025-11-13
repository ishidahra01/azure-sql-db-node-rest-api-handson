# Function App Code Deployment Script for PowerShell
# PowerShell equivalent of deploy-function-code.sh
#
# Bicep でデプロイした Function App にコードと設定をデプロイするスクリプト
# 
# 使い方: .\deploy-function-code.ps1 <resource-group-name>
# 例: .\deploy-function-code.ps1 rg-hands-on-1113
#
# 前提条件:
# - main.bicep で Azure リソースがデプロイ済み
# - local.settings.json が存在する
# - Azure CLI でログイン済み
# - Azure Functions Core Tools がインストール済み

# Exit on error
$ErrorActionPreference = "Stop"

Write-Host "=== Function App Code Deployment Script ===" -ForegroundColor Cyan
Write-Host ""

# コマンドライン引数からリソースグループ名を取得
if ($args.Count -eq 0) {
    Write-Host "Error: Resource group name is required." -ForegroundColor Red
    Write-Host ""
    Write-Host "Usage: .\deploy-function-code.ps1 <resource-group-name>"
    exit 1
}

$resourceGroup = $args[0]

Write-Host "This script deploys your local code to the Function App created by Bicep."
Write-Host ""

# パラメータファイルから値を読み取る
$parametersFile = "./main.parameters.json"
if (!(Test-Path $parametersFile)) {
    Write-Host "Error: $parametersFile not found." -ForegroundColor Red
    Write-Host "Please ensure your Bicep deployment parameters file exists."
    exit 1
}

# JSON ファイルを読み込み
$parametersContent = Get-Content $parametersFile -Raw | ConvertFrom-Json

# パラメータから値を取得
$nameSuffix = $parametersContent.parameters.nameSuffix.value
$env = $parametersContent.parameters.env.value
$location = $parametersContent.parameters.location.value
$sqlAdminUsername = $parametersContent.parameters.sqlAdminUsername.value
$sqlAdminPassword = $parametersContent.parameters.sqlAdminPassword.value

if (($null -eq $nameSuffix) -or ($null -eq $env)) {
    Write-Host "Error: Could not read nameSuffix or env from $parametersFile" -ForegroundColor Red
    exit 1
}

# リソース名を生成（Bicep の命名規則に合わせる）
$functionAppName = "func-${nameSuffix}-${env}"

Write-Host "Target Resource Group: $resourceGroup"
Write-Host "Target Function App: $functionAppName"
Write-Host "Location: $location"
Write-Host ""

# リソースグループの存在確認
try {
    az group show -n $resourceGroup 2>&1 | Out-Null
    if ($LASTEXITCODE -ne 0) {
        throw "Resource group not found"
    }
} catch {
    Write-Host "Error: Resource group '$resourceGroup' not found." -ForegroundColor Red
    Write-Host "Please deploy the Bicep template first:"
    Write-Host "  az deployment group create --resource-group $resourceGroup --template-file main.bicep --parameters main.parameters.json"
    exit 1
}

# Function App の存在確認
try {
    az functionapp show -g $resourceGroup -n $functionAppName 2>&1 | Out-Null
    if ($LASTEXITCODE -ne 0) {
        throw "Function App not found"
    }
} catch {
    Write-Host "Error: Function App '$functionAppName' not found in resource group '$resourceGroup'." -ForegroundColor Red
    Write-Host "Please deploy the Bicep template first."
    exit 1
}

Write-Host "Function App found. Proceeding with deployment..." -ForegroundColor Green
Write-Host ""

# local.settings.json の存在確認
$settingsFile = "./local.settings.json"
if (!(Test-Path $settingsFile)) {
    Write-Host "Error: $settingsFile not found." -ForegroundColor Red
    Write-Host "Please create it from local.settings.json.template:"
    Write-Host "  cp local.settings.json.template local.settings.json"
    Write-Host "  # Edit local.settings.json with your database connection details"
    exit 1
}

# SQL Server 名を取得（Bicep の出力から）
Write-Host "Retrieving SQL Server name from deployment outputs..." -ForegroundColor Green
$deploymentName = az deployment group list -g $resourceGroup --query "[?contains(name, 'main') || contains(name, 'handson')].name | [0]" -o tsv

if ([string]::IsNullOrEmpty($deploymentName)) {
    Write-Host "Warning: Could not find deployment name. Using parameters to construct SQL Server name..." -ForegroundColor Yellow
    # uniqueString をシミュレート（完全には一致しないが概算）
    $rgId = az group show -n $resourceGroup --query id -o tsv
    # PowerShell で MD5 ハッシュを計算
    $md5 = New-Object -TypeName System.Security.Cryptography.MD5CryptoServiceProvider
    $utf8 = New-Object -TypeName System.Text.UTF8Encoding
    $hash = [System.BitConverter]::ToString($md5.ComputeHash($utf8.GetBytes($rgId)))
    $uniqueId = $hash.Replace("-", "").Substring(0, 6).ToLower()
    $sqlServerName = "sql-${nameSuffix}-${env}-${uniqueId}"
} else {
    $sqlServerName = az deployment group show -g $resourceGroup -n $deploymentName --query properties.outputs.sqlServerName.value -o tsv
}

$sqlDatabaseName = "sqldb-${nameSuffix}-${env}"

Write-Host "SQL Server: $sqlServerName"
Write-Host "SQL Database: $sqlDatabaseName"
Write-Host ""

# アプリケーション設定を更新
Write-Host "Updating Function App settings..." -ForegroundColor Green

# Application Insights の接続文字列を取得
$appInsightsName = "appi-${nameSuffix}-${env}"
try {
    $aiConnectionString = az resource show -g $resourceGroup -n $appInsightsName --resource-type "Microsoft.Insights/components" --query properties.ConnectionString -o tsv 2>&1
    if ($LASTEXITCODE -ne 0) {
        $aiConnectionString = ""
    }
} catch {
    $aiConnectionString = ""
}

# データベース設定を local.settings.json から読み取る（フォールバック用）
$settingsContent = Get-Content $settingsFile -Raw | ConvertFrom-Json
$db_server_local = $settingsContent.Values.db_server
$db_database_local = $settingsContent.Values.db_database
$db_user_local = $settingsContent.Values.db_user
$db_password_local = $settingsContent.Values.db_password

# データベース設定を決定（Bicep の値を優先、なければ local.settings.json の値を使用）
$db_server = "${sqlServerName}.database.windows.net"
$db_database = $sqlDatabaseName
$db_user = $sqlAdminUsername
$db_password = $sqlAdminPassword

# local.settings.json に有効な値があればそちらを優先（開発時の柔軟性を保つ）
if (($null -ne $db_server_local) -and ($db_server_local -ne "<yourserver>.database.windows.net")) {
    Write-Host "Using database server from local.settings.json: $db_server_local" -ForegroundColor Yellow
    $db_server = $db_server_local
}
if (($null -ne $db_database_local) -and ($db_database_local -ne "hands_on_db")) {
    $db_database = $db_database_local
}
if (($null -ne $db_user_local) -and ($db_user_local -ne "<your_admin_user>")) {
    $db_user = $db_user_local
}
if (($null -ne $db_password_local) -and ($db_password_local -ne "<your_password>")) {
    $db_password = $db_password_local
}

# アプリケーション設定を更新

Write-Host "Setting core app settings (worker runtime, node version, run from package)..." -ForegroundColor Green
az functionapp config appsettings set -g $resourceGroup -n $functionAppName --settings `
    FUNCTIONS_WORKER_RUNTIME="node" `
    FUNCTIONS_EXTENSION_VERSION="~4" `
    WEBSITE_NODE_DEFAULT_VERSION="~22" `
    WEBSITE_RUN_FROM_PACKAGE="1"

Write-Host "Setting Application Insights..." -ForegroundColor Green
az functionapp config appsettings set -g $resourceGroup -n $functionAppName --settings `
    APPLICATIONINSIGHTS_CONNECTION_STRING="$aiConnectionString"

Write-Host "Setting DB connection settings..." -ForegroundColor Green
az functionapp config appsettings set -g $resourceGroup -n $functionAppName --settings `
    db_server="$db_server" `
    db_database="$db_database" `
    db_user="$db_user" `
    db_password="$db_password"

Write-Host "✓ Function App settings updated." -ForegroundColor Green
Write-Host ""

# npm install（本番用パッケージのみ）
Write-Host "Installing production dependencies..." -ForegroundColor Green
npm install --production

# Function App にデプロイ
Write-Host ""
Write-Host "Deploying code to Function App..." -ForegroundColor Green
func azure functionapp publish $functionAppName --javascript

Write-Host ""
Write-Host "========================================" -ForegroundColor Green
Write-Host "Deployment completed successfully!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host "Function App Name: $functionAppName"
Write-Host "Resource Group: $resourceGroup"
Write-Host ""
Write-Host "You can test your API at:"
Write-Host "https://${functionAppName}.azurewebsites.net/api/customer/123"
Write-Host ""
Write-Host "To view logs, run:"
Write-Host "  func azure functionapp logstream $functionAppName"
Write-Host ""
Write-Host "To test the API via APIM, use:" -ForegroundColor Yellow
$apimName = "apim-${nameSuffix}-${env}"
try {
    $apimUrl = az apim show -g $resourceGroup -n $apimName --query gatewayUrl -o tsv 2>&1
    if (($LASTEXITCODE -eq 0) -and (![string]::IsNullOrEmpty($apimUrl))) {
        Write-Host "  curl ${apimUrl}/api/customer/123 -H 'Ocp-Apim-Subscription-Key: <your-subscription-key>'"
    }
} catch {
    # APIM がない場合は無視
}
Write-Host ""
Write-Host "Done." -ForegroundColor Green
