// Azure PaaS ハンズオン用 Bicep テンプレート（本番構成）
// Front Door → API Management → Functions → SQL Database
// このファイルは、ハンズオンで使用する Azure リソースを宣言的に定義します

// パラメータ
@description('リソースグループの場所')
param location string = 'useast2'

@description('環境識別子（dev, stg, prod など）')
param env string = 'dev'

@description('プロジェクト名（リソース名のプレフィックス）')
param nameSuffix string = 'handson'

@description('Azure SQL 管理者ユーザー名')
param sqlAdminUsername string = 'sqladmin'

@description('Azure SQL 管理者パスワード')
@secure()
param sqlAdminPassword string

@description('SQL Server のファイアウォールで許可する IP アドレスリスト（開発用途）')
param allowedIps array = []

@description('API Management の SKU 名（Developer または Premium）')
@allowed([
  'Developer'
  'Premium'
])
param apimSkuName string = 'Developer'

@description('API Management の SKU キャパシティ')
param apimSkuCapacity int = 1

@description('APIM の管理者メールアドレス')
param apimPublisherEmail string = 'admin@example.com'

@description('APIM の組織名')
param apimPublisherName string = 'Contoso'

@description('Private Endpoint を有効化するか（将来の拡張用）')
param enablePrivateEndpoints bool = false

// 変数（ネーミング規則に準拠）
var uniqueId = uniqueString(resourceGroup().id)
var storageAccountName = 'st${nameSuffix}${env}${take(uniqueId, 8)}'
var functionAppName = 'func-${nameSuffix}-${env}'
var appServicePlanName = 'asp-${nameSuffix}-${env}'
var applicationInsightsName = 'appi-${nameSuffix}-${env}'
var sqlServerName = 'sql-${nameSuffix}-${env}-${take(uniqueId, 6)}'
var sqlDatabaseName = 'sqldb-${nameSuffix}-${env}'
var apimName = 'apim-${nameSuffix}-${env}'
var frontDoorName = 'afd-${nameSuffix}-${env}'
var wafPolicyName = 'waf-${nameSuffix}-${env}'

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
  tags: {
    SecurityControl: 'Ignore'
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
          value: '${sqlServer.name}${environment().suffixes.sqlServerHostname}'
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
    restrictOutboundNetworkAccess: 'Disabled'
  }
  tags: {
    SecurityControl: 'Ignore'
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
  tags: {
    SecurityControl: 'Ignore'
  }
}

// Virtual Network Rule: Azure 内のリソースからのアクセスを許可
resource sqlVirtualNetworkRule 'Microsoft.Sql/servers/virtualNetworkRules@2022-05-01-preview' = {
  parent: sqlServer
  name: 'AllowAzureServices'
  properties: {
    virtualNetworkSubnetId: '/subscriptions/${subscription().subscriptionId}/resourceGroups/${resourceGroup().name}/providers/Microsoft.Network/virtualNetworks/default/subnets/default'
    ignoreMissingVnetServiceEndpoint: true
  }
}

// ファイアウォールルール: Azure サービスを許可
resource sqlFirewallRuleAzure 'Microsoft.Sql/servers/firewallRules@2022-05-01-preview' = {
  parent: sqlServer
  name: 'AllowAllWindowsAzureIps'
  properties: {
    startIpAddress: '0.0.0.0'
    endIpAddress: '0.0.0.0'
  }
}

// ファイアウォールルール: 許可された IP アドレスリスト
resource sqlFirewallRules 'Microsoft.Sql/servers/firewallRules@2022-05-01-preview' = [for (ip, i) in allowedIps: {
  parent: sqlServer
  name: 'AllowedIP-${i}'
  properties: {
    startIpAddress: ip
    endIpAddress: ip
  }
}]

// API Management
resource apiManagement 'Microsoft.ApiManagement/service@2023-05-01-preview' = {
  name: apimName
  location: location
  sku: {
    name: apimSkuName
    capacity: apimSkuCapacity
  }
  properties: {
    publisherEmail: apimPublisherEmail
    publisherName: apimPublisherName
    virtualNetworkType: enablePrivateEndpoints ? 'Internal' : 'None'
  }
  identity: {
    type: 'SystemAssigned'
  }
}

// APIM API: Functions へのプロキシ
resource apimApi 'Microsoft.ApiManagement/service/apis@2023-05-01-preview' = {
  parent: apiManagement
  name: 'customer-api'
  properties: {
    displayName: 'Customer API'
    path: 'api'
    protocols: [
      'https'
    ]
    subscriptionRequired: true
    isCurrent: true
  }
}

// APIM Operation: GET /customer/{id}
resource apimOperation 'Microsoft.ApiManagement/service/apis/operations@2023-05-01-preview' = {
  parent: apimApi
  name: 'get-customer-by-id'
  properties: {
    displayName: 'Get Customer By ID'
    method: 'GET'
    urlTemplate: '/customer/{id}'
    templateParameters: [
      {
        name: 'id'
        type: 'string'
        required: true
      }
    ]
  }
}

// APIM Policy: Functions へのバックエンド転送
resource apimOperationPolicy 'Microsoft.ApiManagement/service/apis/operations/policies@2023-05-01-preview' = {
  parent: apimOperation
  name: 'policy'
  properties: {
    format: 'rawxml'
    value: '''
<policies>
  <inbound>
    <base />
    <set-backend-service base-url="https://${functionApp.properties.defaultHostName}" />
  </inbound>
  <backend>
    <base />
  </backend>
  <outbound>
    <base />
  </outbound>
  <on-error>
    <base />
  </on-error>
</policies>
'''
  }
}

// WAF Policy for Front Door
resource wafPolicy 'Microsoft.Network/FrontDoorWebApplicationFirewallPolicies@2022-05-01' = {
  name: wafPolicyName
  location: 'Global'
  sku: {
    name: 'Premium_AzureFrontDoor'
  }
  properties: {
    policySettings: {
      enabledState: 'Enabled'
      mode: 'Prevention'
    }
    managedRules: {
      managedRuleSets: [
        {
          ruleSetType: 'Microsoft_DefaultRuleSet'
          ruleSetVersion: '2.1'
        }
        {
          ruleSetType: 'Microsoft_BotManagerRuleSet'
          ruleSetVersion: '1.0'
        }
      ]
    }
  }
}

// Azure Front Door Profile
resource frontDoorProfile 'Microsoft.Cdn/profiles@2023-05-01' = {
  name: frontDoorName
  location: 'Global'
  sku: {
    name: 'Premium_AzureFrontDoor'
  }
  properties: {
    originResponseTimeoutSeconds: 60
  }
}

// Front Door Endpoint
resource frontDoorEndpoint 'Microsoft.Cdn/profiles/afdEndpoints@2023-05-01' = {
  parent: frontDoorProfile
  name: 'ep-${nameSuffix}-${env}'
  location: 'Global'
  properties: {
    enabledState: 'Enabled'
  }
}

// Origin Group (APIM)
resource frontDoorOriginGroup 'Microsoft.Cdn/profiles/originGroups@2023-05-01' = {
  parent: frontDoorProfile
  name: 'apim-origin-group'
  properties: {
    loadBalancingSettings: {
      sampleSize: 4
      successfulSamplesRequired: 3
      additionalLatencyInMilliseconds: 50
    }
    healthProbeSettings: {
      probePath: '/status-0123456789abcdef'
      probeRequestType: 'GET'
      probeProtocol: 'Https'
      probeIntervalInSeconds: 100
    }
  }
}

// Origin (APIM Backend)
resource frontDoorOrigin 'Microsoft.Cdn/profiles/originGroups/origins@2023-05-01' = {
  parent: frontDoorOriginGroup
  name: 'apim-origin'
  properties: {
    hostName: '${apimName}.azure-api.net'
    httpPort: 80
    httpsPort: 443
    originHostHeader: '${apimName}.azure-api.net'
    priority: 1
    weight: 1000
    enabledState: 'Enabled'
  }
}

// Front Door Route
resource frontDoorRoute 'Microsoft.Cdn/profiles/afdEndpoints/routes@2023-05-01' = {
  parent: frontDoorEndpoint
  name: 'default-route'
  properties: {
    originGroup: {
      id: frontDoorOriginGroup.id
    }
    supportedProtocols: [
      'Https'
    ]
    patternsToMatch: [
      '/*'
    ]
    forwardingProtocol: 'HttpsOnly'
    linkToDefaultDomain: 'Enabled'
    httpsRedirect: 'Enabled'
  }
  dependsOn: [
    frontDoorOrigin
  ]
}

// Security Policy (WAF)
resource frontDoorSecurityPolicy 'Microsoft.Cdn/profiles/securityPolicies@2023-05-01' = {
  parent: frontDoorProfile
  name: 'security-policy'
  properties: {
    parameters: {
      type: 'WebApplicationFirewall'
      wafPolicy: {
        id: wafPolicy.id
      }
      associations: [
        {
          domains: [
            {
              id: frontDoorEndpoint.id
            }
          ]
          patternsToMatch: [
            '/*'
          ]
        }
      ]
    }
  }
}


// 出力
output functionAppName string = functionApp.name
output functionAppUrl string = 'https://${functionApp.properties.defaultHostName}'
output sqlServerName string = sqlServer.name
output sqlDatabaseName string = sqlDatabase.name
output storageAccountName string = storageAccount.name
output applicationInsightsName string = applicationInsights.name
output apimName string = apiManagement.name
output apimGatewayUrl string = 'https://${apiManagement.properties.gatewayUrl}'
output frontDoorEndpointUrl string = 'https://${frontDoorEndpoint.properties.hostName}'
output frontDoorProfileName string = frontDoorProfile.name
