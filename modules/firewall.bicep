// Azure Firewall モジュール: IDPS有効化
@description('デプロイ先のリージョン')
param location string

@description('環境識別子')
param env string

@description('プロジェクト名')
param projectName string

@description('Firewallサブネット ID')
param firewallSubnetId string

// 変数
var firewallName = 'afw-${projectName}-${env}'
var firewallPolicyName = 'afwpol-${projectName}-${env}'
var publicIpName = 'pip-firewall-${projectName}-${env}'

// Public IP for Firewall
resource publicIp 'Microsoft.Network/publicIPAddresses@2023-05-01' = {
  name: publicIpName
  location: location
  sku: {
    name: 'Standard'
  }
  properties: {
    publicIPAllocationMethod: 'Static'
    publicIPAddressVersion: 'IPv4'
  }
}

// Firewall Policy with IDPS
resource firewallPolicy 'Microsoft.Network/firewallPolicies@2023-05-01' = {
  name: firewallPolicyName
  location: location
  properties: {
    sku: {
      tier: 'Premium'
    }
    threatIntelMode: 'Alert'
    intrusionDetection: {
      mode: 'Alert'
      configuration: {
        signatureOverrides: []
        bypassTrafficSettings: []
      }
    }
    dnsSettings: {
      enableProxy: true
    }
  }
}

// Application Rule Collection for APIM
resource appRuleCollection 'Microsoft.Network/firewallPolicies/ruleCollectionGroups@2023-05-01' = {
  parent: firewallPolicy
  name: 'DefaultApplicationRuleCollectionGroup'
  properties: {
    priority: 300
    ruleCollections: [
      {
        ruleCollectionType: 'FirewallPolicyFilterRuleCollection'
        action: {
          type: 'Allow'
        }
        rules: [
          {
            ruleType: 'ApplicationRule'
            name: 'AllowApiManagement'
            protocols: [
              {
                protocolType: 'Http'
                port: 80
              }
              {
                protocolType: 'Https'
                port: 443
              }
            ]
            targetFqdns: [
              '*'
            ]
            sourceAddresses: [
              '*'
            ]
          }
        ]
        name: 'AllowApimTraffic'
        priority: 100
      }
    ]
  }
}

// Azure Firewall
resource firewall 'Microsoft.Network/azureFirewalls@2023-05-01' = {
  name: firewallName
  location: location
  properties: {
    sku: {
      name: 'AZFW_VNet'
      tier: 'Premium'
    }
    ipConfigurations: [
      {
        name: 'firewallConfig'
        properties: {
          publicIPAddress: {
            id: publicIp.id
          }
          subnet: {
            id: firewallSubnetId
          }
        }
      }
    ]
    firewallPolicy: {
      id: firewallPolicy.id
    }
  }
}

// 出力
output firewallId string = firewall.id
output firewallName string = firewall.name
output firewallPrivateIp string = firewall.properties.ipConfigurations[0].properties.privateIPAddress
output firewallPublicIp string = publicIp.properties.ipAddress
