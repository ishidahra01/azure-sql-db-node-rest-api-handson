// Azure Front Door モジュール: Private Link で Application Gateway に接続
// Front Door Premium SKU が Private Link Origin をサポート
@description('環境識別子')
param env string

@description('プロジェクト名')
param projectName string

@description('Application Gateway のリソース ID')
param appGwResourceId string

@description('Application Gateway の Private Link 構成 ID')
param appGwPrivateLinkConfigId string

@description('Application Gateway のプライベート IP アドレス')
param appGwPrivateIp string

// 変数
var frontDoorName = 'afd-${projectName}-${env}'
var endpointName = 'ep-${projectName}-${env}'

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
  name: endpointName
  location: 'Global'
  properties: {
    enabledState: 'Enabled'
  }
}

// Origin Group (Application Gateway)
resource frontDoorOriginGroup 'Microsoft.Cdn/profiles/originGroups@2023-05-01' = {
  parent: frontDoorProfile
  name: 'appgw-origin-group'
  properties: {
    loadBalancingSettings: {
      sampleSize: 4
      successfulSamplesRequired: 3
      additionalLatencyInMilliseconds: 50
    }
    healthProbeSettings: {
      probePath: '/'
      probeRequestType: 'GET'
      probeProtocol: 'Http'
      probeIntervalInSeconds: 100
    }
  }
}

// Origin (Application Gateway) - Private Link 接続
// Front Door Premium は Private Link Origin をサポート
resource frontDoorOrigin 'Microsoft.Cdn/profiles/originGroups/origins@2023-05-01' = {
  parent: frontDoorOriginGroup
  name: 'appgw-origin'
  properties: {
    hostName: appGwPrivateIp
    httpPort: 80
    httpsPort: 443
    originHostHeader: appGwPrivateIp
    priority: 1
    weight: 1000
    enabledState: 'Enabled'
    // Private Link 設定
    sharedPrivateLinkResource: {
      privateLink: {
        id: appGwResourceId
      }
      privateLinkLocation: resourceGroup().location
      groupId: appGwPrivateLinkConfigId
      requestMessage: 'Front Door Private Link request'
    }
  }
}

// Front Door Route
// Internet → Front Door: HTTPS
// Front Door → AppGW: HTTP (Private Link 経由)
resource frontDoorRoute 'Microsoft.Cdn/profiles/afdEndpoints/routes@2023-05-01' = {
  parent: frontDoorEndpoint
  name: 'default-route'
  properties: {
    originGroup: {
      id: frontDoorOriginGroup.id
    }
    supportedProtocols: [
      'Http'
      'Https'
    ]
    patternsToMatch: [
      '/*'
    ]
    forwardingProtocol: 'HttpOnly'
    linkToDefaultDomain: 'Enabled'
    httpsRedirect: 'Enabled'  // インターネットからは HTTPS を強制
  }
  dependsOn: [
    frontDoorOrigin
  ]
}

// 出力
output frontDoorId string = frontDoorProfile.id
output frontDoorName string = frontDoorProfile.name
output frontDoorEndpointUrl string = 'https://${frontDoorEndpoint.properties.hostName}'
output frontDoorEndpointHostName string = frontDoorEndpoint.properties.hostName
