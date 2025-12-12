// Azure Functions モジュール: Premium プラン + VNet統合
@description('デプロイ先のリージョン')
param location string

@description('環境識別子')
param env string

@description('プロジェクト名')
param projectName string

@description('Functions サブネット ID')
param functionsSubnetId string

@description('Private Endpoint サブネット ID')
param privateEndpointSubnetId string

@description('SQL Server FQDN')
param sqlServerFqdn string

@description('SQL Database 名')
param sqlDatabaseName string

@description('SQL 管理者ユーザー名')
param sqlAdminUsername string

@description('SQL 管理者パスワード')
@secure()
param sqlAdminPassword string

@description('Application Insights の Instrumentation Key')
param appInsightsInstrumentationKey string

@description('Storage Account 接続文字列')
@secure()
param storageAccountConnectionString string

// 変数
var uniqueId = uniqueString(resourceGroup().id)
var functionAppName = 'func-${projectName}-${env}'
var appServicePlanName = 'asp-${projectName}-${env}'
var privateEndpointName = 'pe-func-${projectName}-${env}'
var privateDnsZoneName = 'privatelink.azurewebsites.net'

// App Service Plan (Premium)
resource appServicePlan 'Microsoft.Web/serverfarms@2022-09-01' = {
  name: appServicePlanName
  location: location
  sku: {
    name: 'EP1'
    tier: 'ElasticPremium'
    family: 'EP'
    capacity: 1
  }
  kind: 'elastic'
  properties: {
    reserved: true
  }
}

// Function App
resource functionApp 'Microsoft.Web/sites@2022-09-01' = {
  name: functionAppName
  location: location
  kind: 'functionapp,linux'
  properties: {
    serverFarmId: appServicePlan.id
    reserved: true
    siteConfig: {
      linuxFxVersion: 'NODE|18'
      appSettings: [
        {
          name: 'AzureWebJobsStorage'
          value: storageAccountConnectionString
        }
        {
          name: 'WEBSITE_CONTENTAZUREFILECONNECTIONSTRING'
          value: storageAccountConnectionString
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
          value: appInsightsInstrumentationKey
        }
        {
          name: 'db_server'
          value: sqlServerFqdn
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
    }
    httpsOnly: true
    publicNetworkAccess: 'Disabled'
    virtualNetworkSubnetId: functionsSubnetId
  }
}

// Private DNS Zone for Functions
resource privateDnsZone 'Microsoft.Network/privateDnsZones@2020-06-01' = {
  name: privateDnsZoneName
  location: 'global'
}

// Private Endpoint for Functions
resource privateEndpoint 'Microsoft.Network/privateEndpoints@2023-05-01' = {
  name: privateEndpointName
  location: location
  properties: {
    subnet: {
      id: privateEndpointSubnetId
    }
    privateLinkServiceConnections: [
      {
        name: '${privateEndpointName}-connection'
        properties: {
          privateLinkServiceId: functionApp.id
          groupIds: [
            'sites'
          ]
        }
      }
    ]
  }
}

// Private DNS Zone Group
resource privateDnsZoneGroup 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2023-05-01' = {
  parent: privateEndpoint
  name: 'default'
  properties: {
    privateDnsZoneConfigs: [
      {
        name: 'config1'
        properties: {
          privateDnsZoneId: privateDnsZone.id
        }
      }
    ]
  }
}

// 出力
output functionAppId string = functionApp.id
output functionAppName string = functionApp.name
output functionAppHostName string = functionApp.properties.defaultHostName
output privateEndpointIp string = privateEndpoint.properties.customDnsConfigs[0].ipAddresses[0]
