// 本格的な構成用の Azure Bicep テンプレート
// Azure Front Door → Private Endpoint → Application Gateway → Azure Firewall → API Management → Private Endpoint → Functions → Private Endpoint → SQL Database

@description('デプロイ先のリージョン')
param location string = 'japaneast'

@description('環境識別子（dev, stg, prod など）')
param env string = 'prod'

@description('プロジェクト名（リソース名のプレフィックス）')
param projectName string = 'handson'

@description('Azure SQL 管理者ユーザー名')
param sqlAdminUsername string = 'sqladmin'

@description('Azure SQL 管理者パスワード')
@secure()
param sqlAdminPassword string

@description('API Management の管理者メールアドレス')
param apimPublisherEmail string = 'admin@example.com'

@description('API Management の組織名')
param apimPublisherName string = 'Contoso'

@description('Application Gateway の TLS 証明書データ (Base64エンコード) - オプション')
@secure()
param tlsCertificateData string = ''

@description('Application Gateway の TLS 証明書パスワード - オプション')
@secure()
param tlsCertificatePassword string = ''

// 変数
var uniqueId = uniqueString(resourceGroup().id)
var storageAccountName = 'st${projectName}${env}${take(uniqueId, 8)}'
var applicationInsightsName = 'appi-${projectName}-${env}'

// Storage Account (Functions 用)
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
    allowBlobPublicAccess: false
    publicNetworkAccess: 'Enabled'
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

// ネットワークモジュール
module network 'modules/network.bicep' = {
  name: 'networkDeployment'
  params: {
    location: location
    env: env
    projectName: projectName
  }
}

// Azure Firewall モジュール
module firewall 'modules/firewall.bicep' = {
  name: 'firewallDeployment'
  params: {
    location: location
    env: env
    projectName: projectName
    firewallSubnetId: network.outputs.firewallSubnetId
  }
}

// Application Gateway モジュール
module appGw 'modules/appgw.bicep' = {
  name: 'appGwDeployment'
  params: {
    location: location
    env: env
    projectName: projectName
    appGwSubnetId: network.outputs.appGwSubnetId
    backendIpAddress: firewall.outputs.firewallPrivateIp
    tlsCertificateData: tlsCertificateData
    tlsCertificatePassword: tlsCertificatePassword
  }
}

// SQL Database モジュール
module sqldb 'modules/sqldb.bicep' = {
  name: 'sqldbDeployment'
  params: {
    location: location
    env: env
    projectName: projectName
    privateEndpointSubnetId: network.outputs.privateEndpointSubnetId
    sqlAdminUsername: sqlAdminUsername
    sqlAdminPassword: sqlAdminPassword
  }
}

// Functions モジュール
module functions 'modules/functions.bicep' = {
  name: 'functionsDeployment'
  params: {
    location: location
    env: env
    projectName: projectName
    functionsSubnetId: network.outputs.functionsSubnetId
    privateEndpointSubnetId: network.outputs.privateEndpointSubnetId
    sqlServerFqdn: sqldb.outputs.sqlServerFqdn
    sqlDatabaseName: sqldb.outputs.sqlDatabaseName
    sqlAdminUsername: sqlAdminUsername
    sqlAdminPassword: sqlAdminPassword
    appInsightsInstrumentationKey: applicationInsights.properties.InstrumentationKey
    storageAccountConnectionString: 'DefaultEndpointsProtocol=https;AccountName=${storageAccount.name};EndpointSuffix=${environment().suffixes.storage};AccountKey=${storageAccount.listKeys().keys[0].value}'
  }
}

// API Management モジュール
module apim 'modules/apim.bicep' = {
  name: 'apimDeployment'
  params: {
    location: location
    env: env
    projectName: projectName
    apimSubnetId: network.outputs.apimSubnetId
    apimPublisherEmail: apimPublisherEmail
    apimPublisherName: apimPublisherName
    functionAppHostName: functions.outputs.functionAppHostName
  }
}

// Azure Front Door モジュール
module frontDoor 'modules/frontdoor.bicep' = {
  name: 'frontDoorDeployment'
  params: {
    env: env
    projectName: projectName
    appGwResourceId: appGw.outputs.appGwId
    appGwPrivateLinkConfigId: appGw.outputs.privateLinkConfigurationId
    appGwPrivateIp: appGw.outputs.appGwPrivateIp
  }
}

// 出力
output vnetName string = network.outputs.vnetName
output firewallName string = firewall.outputs.firewallName
output firewallPrivateIp string = firewall.outputs.firewallPrivateIp
output appGwName string = appGw.outputs.appGwName
output appGwPublicIp string = appGw.outputs.appGwPublicIp
output sqlServerName string = sqldb.outputs.sqlServerName
output sqlDatabaseName string = sqldb.outputs.sqlDatabaseName
output functionAppName string = functions.outputs.functionAppName
output apimName string = apim.outputs.apimName
output apimGatewayUrl string = apim.outputs.apimGatewayUrl
output frontDoorEndpointUrl string = frontDoor.outputs.frontDoorEndpointUrl
output storageAccountName string = storageAccount.name
output applicationInsightsName string = applicationInsights.name

output deploymentInstructions string = '''
デプロイが完了しました！

次のステップ:
1. Front Door Private Link の承認:
   - Azure Portal で Application Gateway を開く
   - Settings → Private Link を選択
   - Front Door からの接続要求を承認

2. SQL スクリプトの実行:
   - Azure Portal で SQL Database を開く
   - Query Editor を使用して sql/HandsOnSetup.sql を実行

3. Function App へのコードデプロイ:
   func azure functionapp publish ${functions.outputs.functionAppName}

4. 動作確認:
   - Front Door 経由 (推奨): ${frontDoor.outputs.frontDoorEndpointUrl}/api/customer/123
   - Application Gateway 経由 (Public IP): http://${appGw.outputs.appGwPublicIp}/api/customer/123

注意: 
- API Management と Front Door のプロビジョニングには 30〜60 分かかります
- Private Link 接続の承認後、Front Door → AppGW の接続が確立されます
- TLS 証明書を設定していない場合、AppGW は HTTP で動作します
'''
