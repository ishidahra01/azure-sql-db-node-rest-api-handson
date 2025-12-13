// API Management モジュール: VNet統合（Internal mode）
@description('デプロイ先のリージョン')
param location string

@description('環境識別子')
param env string

@description('プロジェクト名')
param projectName string

@description('API Management サブネット ID')
param apimSubnetId string

@description('APIM 管理者メールアドレス')
param apimPublisherEmail string

@description('APIM 組織名')
param apimPublisherName string

@description('Functions のホスト名')
param functionAppHostName string

// 変数
var apimName = 'apim-${projectName}-${env}'

// API Management (Premium SKU for VNet Integration)
resource apiManagement 'Microsoft.ApiManagement/service@2023-05-01-preview' = {
  name: apimName
  location: location
  sku: {
    name: 'Premium'
    capacity: 1
  }
  properties: {
    publisherEmail: apimPublisherEmail
    publisherName: apimPublisherName
    virtualNetworkType: 'Internal'
    virtualNetworkConfiguration: {
      subnetResourceId: apimSubnetId
    }
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
      'http'
      'https'
    ]
    subscriptionRequired: false
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
    value: format('''
<policies>
  <inbound>
    <base />
    <set-backend-service base-url="https://{0}/api" />
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
''', functionAppHostName)
  }
}

// 出力
output apimId string = apiManagement.id
output apimName string = apiManagement.name
output apimPrivateIp string = apiManagement.properties.privateIPAddresses[0]
output apimGatewayUrl string = apiManagement.properties.gatewayUrl
