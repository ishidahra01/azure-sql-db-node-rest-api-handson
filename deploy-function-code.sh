#!/bin/bash

set -euo pipefail

# Bicep でデプロイした Function App にコードと設定をデプロイするスクリプト
# 
# 使い方: ./deploy-function-code.sh <resource-group-name>
# 例: ./deploy-function-code.sh rg-hands-on-1113
#
# 前提条件:
# - main.bicep で Azure リソースがデプロイ済み
# - local.settings.json が存在する
# - Azure CLI でログイン済み
# - Azure Functions Core Tools がインストール済み

echo "=== Function App Code Deployment Script ==="
echo ""

# コマンドライン引数からリソースグループ名を取得
if [ $# -eq 0 ]; then
    echo "Error: Resource group name is required."
    echo ""
    echo "Usage: $0 <resource-group-name>"
    exit 1
fi

resourceGroup="$1"

echo "This script deploys your local code to the Function App created by Bicep."
echo ""

# パラメータファイルから値を読み取る
parametersFile="./main.parameters.json"
if [ ! -f "$parametersFile" ]; then
    echo "Error: $parametersFile not found."
    echo "Please ensure your Bicep deployment parameters file exists."
    exit 1
fi

# jq で parameters.json から値を取得
nameSuffix=$(jq -r '.parameters.nameSuffix.value' "$parametersFile")
env=$(jq -r '.parameters.env.value' "$parametersFile")
location=$(jq -r '.parameters.location.value' "$parametersFile")
sqlAdminUsername=$(jq -r '.parameters.sqlAdminUsername.value' "$parametersFile")
sqlAdminPassword=$(jq -r '.parameters.sqlAdminPassword.value' "$parametersFile")

if [ "$nameSuffix" == "null" ] || [ "$env" == "null" ]; then
    echo "Error: Could not read nameSuffix or env from $parametersFile"
    exit 1
fi

# リソース名を生成（Bicep の命名規則に合わせる）
functionAppName="func-${nameSuffix}-${env}"

echo "Target Resource Group: $resourceGroup"
echo "Target Function App: $functionAppName"
echo "Location: $location"
echo ""

# リソースグループの存在確認
if ! az group show -n "$resourceGroup" &>/dev/null; then
    echo "Error: Resource group '$resourceGroup' not found."
    echo "Please deploy the Bicep template first:"
    echo "  az deployment group create --resource-group $resourceGroup --template-file main.bicep --parameters main.parameters.json"
    exit 1
fi

# Function App の存在確認
if ! az functionapp show -g "$resourceGroup" -n "$functionAppName" &>/dev/null; then
    echo "Error: Function App '$functionAppName' not found in resource group '$resourceGroup'."
    echo "Please deploy the Bicep template first."
    exit 1
fi

echo "Function App found. Proceeding with deployment..."
echo ""

# local.settings.json の存在確認
settingsFile="./local.settings.json"
if [ ! -f "$settingsFile" ]; then
    echo "Error: $settingsFile not found."
    echo "Please create it from local.settings.json.template:"
    echo "  cp local.settings.json.template local.settings.json"
    echo "  # Edit local.settings.json with your database connection details"
    exit 1
fi

# SQL Server 名を取得（Bicep の出力から）
echo "Retrieving SQL Server name from deployment outputs..."
deploymentName=$(az deployment group list -g "$resourceGroup" --query "[?contains(name, 'main') || contains(name, 'handson')].name | [0]" -o tsv)

if [ -z "$deploymentName" ]; then
    echo "Warning: Could not find deployment name. Using parameters to construct SQL Server name..."
    # uniqueString をシミュレート（完全には一致しないが概算）
    rgId=$(az group show -n "$resourceGroup" --query id -o tsv)
    uniqueId=$(echo -n "$rgId" | md5sum | cut -c1-6)
    sqlServerName="sql-${nameSuffix}-${env}-${uniqueId}"
else
    sqlServerName=$(az deployment group show -g "$resourceGroup" -n "$deploymentName" --query properties.outputs.sqlServerName.value -o tsv)
fi

sqlDatabaseName="sqldb-${nameSuffix}-${env}"

echo "SQL Server: $sqlServerName"
echo "SQL Database: $sqlDatabaseName"
echo ""

# アプリケーション設定を更新
echo "Updating Function App settings..."

# Application Insights の接続文字列を取得
appInsightsName="appi-${nameSuffix}-${env}"
aiConnectionString=$(az resource show -g "$resourceGroup" -n "$appInsightsName" --resource-type "Microsoft.Insights/components" --query properties.ConnectionString -o tsv 2>/dev/null || echo "")


# データベース設定を local.settings.json から読み取る（フォールバック用）
db_server_local=$(jq -r '.Values.db_server' "$settingsFile")
db_database_local=$(jq -r '.Values.db_database' "$settingsFile")
db_user_local=$(jq -r '.Values.db_user' "$settingsFile")
db_password_local=$(jq -r '.Values.db_password' "$settingsFile")

# データベース設定を決定（Bicep の値を優先、なければ local.settings.json の値を使用）
db_server="${sqlServerName}.database.windows.net"
db_database="$sqlDatabaseName"
db_user="${sqlAdminUsername}"
db_password="${sqlAdminPassword}"

# local.settings.json に有効な値があればそちらを優先（開発時の柔軟性を保つ）
if [ "$db_server_local" != "null" ] && [ "$db_server_local" != "<yourserver>.database.windows.net" ]; then
    echo "Using database server from local.settings.json: $db_server_local"
    db_server="$db_server_local"
fi
if [ "$db_database_local" != "null" ] && [ "$db_database_local" != "hands_on_db" ]; then
    db_database="$db_database_local"
fi
if [ "$db_user_local" != "null" ] && [ "$db_user_local" != "<your_admin_user>" ]; then
    db_user="$db_user_local"
fi
if [ "$db_password_local" != "null" ] && [ "$db_password_local" != "<your_password>" ]; then
    db_password="$db_password_local"
fi

# アプリケーション設定を更新

echo "Setting core app settings (worker runtime, node version, run from package)..."
az functionapp config appsettings set -g "$resourceGroup" -n "$functionAppName" --settings FUNCTIONS_WORKER_RUNTIME="node" FUNCTIONS_EXTENSION_VERSION="~4" WEBSITE_NODE_DEFAULT_VERSION="~22" WEBSITE_RUN_FROM_PACKAGE="1"

echo "Setting Application Insights..."
az functionapp config appsettings set -g "$resourceGroup" -n "$functionAppName" --settings APPLICATIONINSIGHTS_CONNECTION_STRING="$aiConnectionString"

echo "Setting DB connection settings..."
az functionapp config appsettings set -g "$resourceGroup" -n "$functionAppName" --settings db_server="$db_server" db_database="$db_database" db_user="$db_user" db_password="$db_password"

echo "✓ Function App settings updated."
echo ""

# npm install（本番用パッケージのみ）
echo "Installing production dependencies..."
npm install --production

# Function App にデプロイ
echo ""
echo "Deploying code to Function App..."
func azure functionapp publish "$functionAppName" --javascript

echo ""
echo "========================================"
echo "Deployment completed successfully!"
echo "========================================"
echo "Function App Name: $functionAppName"
echo "Resource Group: $resourceGroup"
echo ""
echo "You can test your API at:"
echo "https://${functionAppName}.azurewebsites.net/api/customer/123"
echo ""
echo "To view logs, run:"
echo "  func azure functionapp logstream $functionAppName"
echo ""
echo "To test the API via APIM, use:"
apimName="apim-${nameSuffix}-${env}"
apimUrl=$(az apim show -g "$resourceGroup" -n "$apimName" --query gatewayUrl -o tsv 2>/dev/null || echo "")
if [ -n "$apimUrl" ]; then
    echo "  curl ${apimUrl}/api/customer/123 -H 'Ocp-Apim-Subscription-Key: <your-subscription-key>'"
fi
echo ""
echo "Done."
