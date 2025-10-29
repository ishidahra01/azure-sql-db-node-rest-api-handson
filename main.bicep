// Azure PaaS ハンズオン用 Bicep テンプレート
// このファイルは、ハンズオンで使用する Azure リソースを宣言的に定義します

// パラメータ
@description('リソースグループの場所')
param location string = 'japaneast'

@description('プロジェクト名のプレフィックス')
param projectName string = 'handson'

@description('Azure SQL 管理者ユーザー名')
param sqlAdminUsername string = 'sqladmin'

@description('Azure SQL 管理者パスワード')
@secure()
param sqlAdminPassword string

@description('開発端末のIPアドレス（ファイアウォール用）')
param clientIpAddress string

// 変数
var storageAccountName = '${projectName}storage${uniqueString(resourceGroup().id)}'
var functionAppName = '${projectName}-func-${uniqueString(resourceGroup().id)}'
var appServicePlanName = '${projectName}-plan'
var applicationInsightsName = '${projectName}-ai'
var sqlServerName = '${projectName}-sql-${uniqueString(resourceGroup().id)}'
var sqlDatabaseName = 'hands_on_db'

// ストレージアカウント（Functions 用）
resource storageAccount 'Microsoft.Storage/storageAccounts@2022-09-01' = {
  name: storageAccountName
  location: location
  sku: {
    name: 'Standard_LRS'
  }
  kind: 'StorageV2'
  properties: {
    supportsHttpsTrafficOnly: true
    minimumTlsVersion: 'TLS1_2'
  }
}

// Application Insights
resource applicationInsights 'Microsoft.Insights/components@2020-02-02' = {
  name: applicationInsightsName
  location: location
  kind: 'web'
  properties: {
    Application_Type: 'web'
    Request_Source: 'rest'
  }
}

// App Service Plan（消費プラン）
resource appServicePlan 'Microsoft.Web/serverfarms@2022-03-01' = {
  name: appServicePlanName
  location: location
  sku: {
    name: 'Y1'
    tier: 'Dynamic'
  }
  properties: {}
}

// Function App
resource functionApp 'Microsoft.Web/sites@2022-03-01' = {
  name: functionAppName
  location: location
  kind: 'functionapp,linux'
  properties: {
    serverFarmId: appServicePlan.id
    siteConfig: {
      appSettings: [
        {
          name: 'AzureWebJobsStorage'
          value: 'DefaultEndpointsProtocol=https;AccountName=${storageAccount.name};EndpointSuffix=${environment().suffixes.storage};AccountKey=${storageAccount.listKeys().keys[0].value}'
        }
        {
          name: 'WEBSITE_CONTENTAZUREFILECONNECTIONSTRING'
          value: 'DefaultEndpointsProtocol=https;AccountName=${storageAccount.name};EndpointSuffix=${environment().suffixes.storage};AccountKey=${storageAccount.listKeys().keys[0].value}'
        }
        {
          name: 'WEBSITE_CONTENTSHARE'
          value: toLower(functionAppName)
        }
        {
          name: 'FUNCTIONS_EXTENSION_VERSION'
          value: '~4'
        }
        {
          name: 'FUNCTIONS_WORKER_RUNTIME'
          value: 'node'
        }
        {
          name: 'WEBSITE_NODE_DEFAULT_VERSION'
          value: '~18'
        }
        {
          name: 'APPINSIGHTS_INSTRUMENTATIONKEY'
          value: applicationInsights.properties.InstrumentationKey
        }
        {
          name: 'db_server'
          value: '${sqlServer.name}.database.windows.net'
        }
        {
          name: 'db_database'
          value: sqlDatabaseName
        }
        {
          name: 'db_user'
          value: sqlAdminUsername
        }
        {
          name: 'db_password'
          value: sqlAdminPassword
        }
      ]
      linuxFxVersion: 'node|18'
    }
    httpsOnly: true
  }
}

// Azure SQL Server
resource sqlServer 'Microsoft.Sql/servers@2022-05-01-preview' = {
  name: sqlServerName
  location: location
  properties: {
    administratorLogin: sqlAdminUsername
    administratorLoginPassword: sqlAdminPassword
    version: '12.0'
    minimalTlsVersion: '1.2'
    publicNetworkAccess: 'Enabled'
  }
}

// Azure SQL Database
resource sqlDatabase 'Microsoft.Sql/servers/databases@2022-05-01-preview' = {
  parent: sqlServer
  name: sqlDatabaseName
  location: location
  sku: {
    name: 'Basic'
    tier: 'Basic'
    capacity: 5
  }
  properties: {
    collation: 'SQL_Latin1_General_CP1_CI_AS'
    maxSizeBytes: 2147483648
    catalogCollation: 'SQL_Latin1_General_CP1_CI_AS'
    zoneRedundant: false
    readScale: 'Disabled'
  }
}

// ファイアウォールルール: Azure サービスを許可
resource sqlFirewallRuleAzure 'Microsoft.Sql/servers/firewallRules@2022-05-01-preview' = {
  parent: sqlServer
  name: 'AllowAzureServices'
  properties: {
    startIpAddress: '0.0.0.0'
    endIpAddress: '0.0.0.0'
  }
}

// ファイアウォールルール: クライアントIPを許可
resource sqlFirewallRuleClient 'Microsoft.Sql/servers/firewallRules@2022-05-01-preview' = {
  parent: sqlServer
  name: 'AllowClientIP'
  properties: {
    startIpAddress: clientIpAddress
    endIpAddress: clientIpAddress
  }
}

// 出力
output functionAppName string = functionApp.name
output functionAppUrl string = 'https://${functionApp.properties.defaultHostName}'
output sqlServerName string = sqlServer.name
output sqlDatabaseName string = sqlDatabase.name
output storageAccountName string = storageAccount.name
output applicationInsightsName string = applicationInsights.name
