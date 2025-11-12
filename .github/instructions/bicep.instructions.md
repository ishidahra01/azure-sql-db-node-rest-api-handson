---
description: Bicep テンプレートのコーディング規則とベストプラクティス
applyTo: "**/*.bicep,**/main.parameters.json"
---

# Bicep Infrastructure as Code ガイドライン

このプロジェクトでは、Azure リソースを Bicep で宣言的に定義します。以下の規則を**厳守**してください。

## ネーミング規則（必須）

すべての Azure リソースは、以下の命名規則に従う必要があります:

| リソースタイプ | 命名パターン | 例 |
|--------------|-------------|-----|
| Resource Group | `rg-<app>-<env>` | `rg-handson-dev`, `rg-handson-prod` |
| Azure Front Door | `afdr-<app>-<env>` | `afdr-handson-dev` |
| API Management | `apim-<app>-<env>` | `apim-handson-dev` |
| Function App | `func-<app>-<env>` | `func-handson-dev` |
| Storage Account | `st<app><env><suffix>` | `sthandsondev123` (24文字以内、小文字のみ) |
| SQL Server | `sql-<app>-<env>` | `sql-handson-dev` |
| SQL Database | `sqldb-<app>-<env>` | `sqldb-handson-dev` |
| Application Insights | `appi-<app>-<env>` | `appi-handson-dev` |
| App Service Plan | `plan-<app>-<env>` | `plan-handson-dev` |

### ネーミングのベストプラクティス

- **一貫性**: すべてのリソースで同じ `<app>` と `<env>` を使用
- **重複回避**: Storage Account や SQL Server はグローバルに一意である必要があるため、`uniqueString()` 関数を使用
- **小文字**: Storage Account 名は小文字と数字のみ (ハイフン不可)
- **長さ制限**: Storage Account は 3-24 文字

## パラメータ管理の原則

### 必須ルール: すべてのパラメータは main.bicep で集約

```bicep
// ✅ 正しい例: main.bicep にすべてのパラメータを定義
@description('デプロイ先のリージョン')
param location string = 'japaneast'

@description('環境名 (dev, staging, prod)')
param env string = 'dev'

@description('アプリケーション名')
param projectName string = 'handson'

@description('SQL Server の管理者パスワード')
@secure()
param sqlAdminPassword string

// モジュールにパラメータを渡す
module functionApp 'modules/functionApp.bicep' = {
  name: 'functionAppDeployment'
  params: {
    location: location
    env: env
    projectName: projectName
  }
}
```

```bicep
// ❌ 間違った例: モジュールでハードコードされた値
module functionApp 'modules/functionApp.bicep' = {
  name: 'functionAppDeployment'
  params: {
    location: 'japaneast'  // ハードコード禁止
    env: 'dev'             // ハードコード禁止
  }
}
```

### パラメータファイルの管理

- `main.parameters.json.template` をベースにする
- 環境ごとに異なるパラメータファイルを作成可能:
  - `main.parameters.dev.json`
  - `main.parameters.staging.json`
  - `main.parameters.prod.json`

```json
{
  "$schema": "https://schema.management.azure.com/schemas/2019-04-01/deploymentParameters.json#",
  "contentVersion": "1.0.0.0",
  "parameters": {
    "location": {
      "value": "japaneast"
    },
    "projectName": {
      "value": "handson"
    },
    "sqlAdminPassword": {
      "value": "YourStrongPassword123!"
    },
    "clientIpAddress": {
      "value": "203.0.113.1"
    }
  }
}
```

## Infrastructure as Code のスコープ

### IaC で行うこと

- ✅ Azure リソースの定義と作成
- ✅ リソース間の依存関係の宣言
- ✅ 初期設定とアプリケーション設定
- ✅ ネットワーク構成
- ✅ セキュリティ設定 (ファイアウォール、TLS など)

### IaC で行わないこと

- ❌ アプリケーションコードのデプロイ
- ❌ データベースのスキーマ作成やデータ投入
- ❌ コードのビルドやパッケージング
- ❌ ランタイムの設定変更 (デプロイ後の動的な設定)

### デプロイの流れ

```bash
# 1. IaC でインフラをデプロイ (Bicep)
az deployment group create \
  --resource-group rg-handson-dev \
  --template-file main.bicep \
  --parameters main.parameters.json

# 2. アプリケーションコードを別途デプロイ (func コマンド)
func azure functionapp publish func-handson-dev

# 3. SQL スクリプトを実行 (Azure Portal または SQL ツール)
# sql/HandsOnSetup.sql を実行
```

## セキュリティのベストプラクティス

### 機密情報の管理

```bicep
// ✅ パスワードには @secure() を使用
@description('SQL Server の管理者パスワード')
@secure()
param sqlAdminPassword string

// ✅ Key Vault 参照を使用 (本番環境推奨)
resource keyVault 'Microsoft.KeyVault/vaults@2022-07-01' existing = {
  name: 'kv-handson-dev'
}

resource sqlServer 'Microsoft.Sql/servers@2022-05-01-preview' = {
  name: sqlServerName
  properties: {
    administratorLoginPassword: keyVault.getSecret('sqlAdminPassword')
  }
}
```

### TLS とネットワークセキュリティ

```bicep
// ✅ TLS 1.2 以上を強制
resource storageAccount 'Microsoft.Storage/storageAccounts@2022-09-01' = {
  name: storageAccountName
  properties: {
    minimumTlsVersion: 'TLS1_2'
    supportsHttpsTrafficOnly: true
  }
}

// ✅ SQL Server で TLS を強制
resource sqlServer 'Microsoft.Sql/servers@2022-05-01-preview' = {
  name: sqlServerName
  properties: {
    minimalTlsVersion: '1.2'
    publicNetworkAccess: 'Enabled'  // 本番では 'Disabled' + Private Link を検討
  }
}
```

## リソース SKU の選択

### 開発環境 (コスト最適化)

```bicep
// Function App: 消費プラン (従量課金)
resource appServicePlan 'Microsoft.Web/serverfarms@2022-03-01' = {
  name: appServicePlanName
  sku: {
    name: 'Y1'
    tier: 'Dynamic'
  }
}

// SQL Database: Basic (最小コスト)
resource sqlDatabase 'Microsoft.Sql/servers/databases@2022-05-01-preview' = {
  name: sqlDatabaseName
  sku: {
    name: 'Basic'
    tier: 'Basic'
    capacity: 5
  }
}
```

### 本番環境 (可用性重視)

```bicep
// Function App: Premium プラン (VNet 統合、コールドスタート回避)
resource appServicePlan 'Microsoft.Web/serverfarms@2022-03-01' = {
  name: appServicePlanName
  sku: {
    name: 'EP1'
    tier: 'ElasticPremium'
  }
}

// SQL Database: Standard (高可用性)
resource sqlDatabase 'Microsoft.Sql/servers/databases@2022-05-01-preview' = {
  name: sqlDatabaseName
  sku: {
    name: 'S3'
    tier: 'Standard'
    capacity: 100
  }
  properties: {
    zoneRedundant: true  // ゾーン冗長
  }
}
```

## モジュール化のベストプラクティス

### ファイル構造

```
├── main.bicep                  # メインテンプレート
├── main.parameters.json        # パラメータファイル
└── modules/
    ├── functionApp.bicep       # Functions モジュール
    ├── sqlDatabase.bicep       # SQL Database モジュール
    ├── networking.bicep        # ネットワークモジュール
    └── monitoring.bicep        # 監視モジュール
```

### モジュールの作成

```bicep
// modules/functionApp.bicep
@description('デプロイ先のリージョン')
param location string

@description('環境名')
param env string

@description('アプリケーション名')
param projectName string

// パラメータから一意な名前を生成
var functionAppName = 'func-${projectName}-${env}'
var storageAccountName = 'st${projectName}${env}${uniqueString(resourceGroup().id)}'

resource functionApp 'Microsoft.Web/sites@2022-03-01' = {
  name: functionAppName
  location: location
  kind: 'functionapp,linux'
  // ... その他のプロパティ
}

output functionAppName string = functionApp.name
output functionAppUrl string = 'https://${functionApp.properties.defaultHostName}'
```

### モジュールの呼び出し

```bicep
// main.bicep
module functionApp 'modules/functionApp.bicep' = {
  name: 'functionAppDeployment'
  params: {
    location: location
    env: env
    projectName: projectName
  }
}

// モジュールの出力を使用
output functionAppUrl string = functionApp.outputs.functionAppUrl
```

## 依存関係の管理

```bicep
// ✅ 明示的な依存関係
resource sqlServer 'Microsoft.Sql/servers@2022-05-01-preview' = {
  name: sqlServerName
  // ...
}

resource sqlDatabase 'Microsoft.Sql/servers/databases@2022-05-01-preview' = {
  parent: sqlServer  // 親リソースとして指定
  name: sqlDatabaseName
  // ...
}

// ✅ dependsOn を使った依存関係
resource functionApp 'Microsoft.Web/sites@2022-03-01' = {
  name: functionAppName
  dependsOn: [
    storageAccount
    appServicePlan
  ]
  // ...
}
```

## デプロイ時のベストプラクティス

### 事前検証

```bash
# 構文チェック
az bicep build --file main.bicep

# What-If 分析 (デプロイせずに変更を確認)
az deployment group what-if \
  --resource-group rg-handson-dev \
  --template-file main.bicep \
  --parameters main.parameters.json
```

### デプロイコマンド

```bash
# リソースグループの作成
az group create --name rg-handson-dev --location japaneast

# Bicep テンプレートのデプロイ
az deployment group create \
  --resource-group rg-handson-dev \
  --template-file main.bicep \
  --parameters main.parameters.json \
  --mode Incremental  # Incremental (増分) または Complete (完全)

# デプロイ結果の確認
az deployment group show \
  --resource-group rg-handson-dev \
  --name main \
  --query properties.outputs
```

## Copilot への指示

Bicep ファイルを編集または作成する際は、以下を必ず守ってください:

1. **ネーミング規則を厳守**: すべてのリソース名は上記の命名パターンに従う
2. **パラメータを main.bicep で集約**: ハードコードされた値は使用しない
3. **IaC のスコープを守る**: アプリケーションコードのデプロイは含めない
4. **セキュリティを最優先**: `@secure()` を使用し、TLS を強制する
5. **既存のパターンに従う**: プロジェクト内の既存の Bicep ファイルのスタイルを維持する

コードを生成する前に、既存の `main.bicep` を確認してパターンを理解してください。
