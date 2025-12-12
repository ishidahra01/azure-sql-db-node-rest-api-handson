// Azure Front Door モジュール: Private Link で Application Gateway に接続
@description('環境識別子')
param env string

@description('プロジェクト名')
param projectName string

@description('Application Gateway のパブリック IP アドレス')
param appGwPublicIp string

@description('Application Gateway の ID')
param appGwId string

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

// Origin (Application Gateway)
resource frontDoorOrigin 'Microsoft.Cdn/profiles/originGroups/origins@2023-05-01' = {
  parent: frontDoorOriginGroup
  name: 'appgw-origin'
  properties: {
    hostName: appGwPublicIp
    httpPort: 80
    httpsPort: 443
    originHostHeader: appGwPublicIp
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
      'Http'
      'Https'
    ]
    patternsToMatch: [
      '/*'
    ]
    forwardingProtocol: 'HttpOnly'
    linkToDefaultDomain: 'Enabled'
    httpsRedirect: 'Disabled'
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
