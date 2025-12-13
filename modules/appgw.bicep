// Application Gateway モジュール
// Private Link 対応: Public + Private フロントエンド IP 構成
@description('デプロイ先のリージョン')
param location string

@description('環境識別子')
param env string

@description('プロジェクト名')
param projectName string

@description('Application Gateway サブネット ID')
param appGwSubnetId string

@description('バックエンド (Firewall) のプライベート IP')
param backendIpAddress string

@description('TLS 証明書データ (Base64エンコード) - オプション')
@secure()
param tlsCertificateData string = ''

@description('TLS 証明書パスワード - オプション')
@secure()
param tlsCertificatePassword string = ''

// 変数
var appGwName = 'appgw-${projectName}-${env}'
var publicIpName = 'pip-appgw-${projectName}-${env}'
var privateLinkConfigName = 'appgw-pl-config'
var hasCertificate = !empty(tlsCertificateData)

// Public IP for Application Gateway
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

// Application Gateway
// Private Link サポート: Public + Private フロントエンド IP が必要
resource applicationGateway 'Microsoft.Network/applicationGateways@2023-05-01' = {
  name: appGwName
  location: location
  properties: {
    sku: {
      name: 'WAF_v2'
      tier: 'WAF_v2'
      capacity: 2
    }
    gatewayIPConfigurations: [
      {
        name: 'appGwIpConfig'
        properties: {
          subnet: {
            id: appGwSubnetId
          }
        }
      }
    ]
    // Private Link 対応: Public と Private 両方のフロントエンド IP が必要
    frontendIPConfigurations: [
      {
        name: 'appGwPublicFrontendIp'
        properties: {
          publicIPAddress: {
            id: publicIp.id
          }
        }
      }
      {
        name: 'appGwPrivateFrontendIp'
        properties: {
          privateIPAllocationMethod: 'Dynamic'
          subnet: {
            id: appGwSubnetId
          }
        }
      }
    ]
    frontendPorts: [
      {
        name: 'port_443'
        properties: {
          port: 443
        }
      }
      {
        name: 'port_80'
        properties: {
          port: 80
        }
      }
    ]
    // SSL 証明書 (提供された場合)
    sslCertificates: hasCertificate ? [
      {
        name: 'appgw-ssl-cert'
        properties: {
          data: tlsCertificateData
          password: tlsCertificatePassword
        }
      }
    ] : []
    backendAddressPools: [
      {
        name: 'firewallBackendPool'
        properties: {
          backendAddresses: [
            {
              ipAddress: backendIpAddress
            }
          ]
        }
      }
    ]
    backendHttpSettingsCollection: [
      {
        name: 'httpSettings'
        properties: {
          port: 80
          protocol: 'Http'
          cookieBasedAffinity: 'Disabled'
          requestTimeout: 30
          pickHostNameFromBackendAddress: false
        }
      }
    ]
    // HTTP と HTTPS リスナー (証明書がある場合は HTTPS を使用)
    httpListeners: hasCertificate ? [
      {
        name: 'httpsListener'
        properties: {
          frontendIPConfiguration: {
            id: resourceId('Microsoft.Network/applicationGateways/frontendIPConfigurations', appGwName, 'appGwPrivateFrontendIp')
          }
          frontendPort: {
            id: resourceId('Microsoft.Network/applicationGateways/frontendPorts', appGwName, 'port_443')
          }
          protocol: 'Https'
          sslCertificate: {
            id: resourceId('Microsoft.Network/applicationGateways/sslCertificates', appGwName, 'appgw-ssl-cert')
          }
        }
      }
      {
        name: 'httpListener'
        properties: {
          frontendIPConfiguration: {
            id: resourceId('Microsoft.Network/applicationGateways/frontendIPConfigurations', appGwName, 'appGwPublicFrontendIp')
          }
          frontendPort: {
            id: resourceId('Microsoft.Network/applicationGateways/frontendPorts', appGwName, 'port_80')
          }
          protocol: 'Http'
        }
      }
    ] : [
      {
        name: 'httpListener'
        properties: {
          frontendIPConfiguration: {
            id: resourceId('Microsoft.Network/applicationGateways/frontendIPConfigurations', appGwName, 'appGwPrivateFrontendIp')
          }
          frontendPort: {
            id: resourceId('Microsoft.Network/applicationGateways/frontendPorts', appGwName, 'port_80')
          }
          protocol: 'Http'
        }
      }
    ]
    requestRoutingRules: hasCertificate ? [
      {
        name: 'httpsRoutingRule'
        properties: {
          ruleType: 'Basic'
          priority: 100
          httpListener: {
            id: resourceId('Microsoft.Network/applicationGateways/httpListeners', appGwName, 'httpsListener')
          }
          backendAddressPool: {
            id: resourceId('Microsoft.Network/applicationGateways/backendAddressPools', appGwName, 'firewallBackendPool')
          }
          backendHttpSettings: {
            id: resourceId('Microsoft.Network/applicationGateways/backendHttpSettingsCollection', appGwName, 'httpSettings')
          }
        }
      }
      {
        name: 'httpRoutingRule'
        properties: {
          ruleType: 'Basic'
          priority: 110
          httpListener: {
            id: resourceId('Microsoft.Network/applicationGateways/httpListeners', appGwName, 'httpListener')
          }
          backendAddressPool: {
            id: resourceId('Microsoft.Network/applicationGateways/backendAddressPools', appGwName, 'firewallBackendPool')
          }
          backendHttpSettings: {
            id: resourceId('Microsoft.Network/applicationGateways/backendHttpSettingsCollection', appGwName, 'httpSettings')
          }
        }
      }
    ] : [
      {
        name: 'routingRule'
        properties: {
          ruleType: 'Basic'
          priority: 100
          httpListener: {
            id: resourceId('Microsoft.Network/applicationGateways/httpListeners', appGwName, 'httpListener')
          }
          backendAddressPool: {
            id: resourceId('Microsoft.Network/applicationGateways/backendAddressPools', appGwName, 'firewallBackendPool')
          }
          backendHttpSettings: {
            id: resourceId('Microsoft.Network/applicationGateways/backendHttpSettingsCollection', appGwName, 'httpSettings')
          }
        }
      }
    ]
    // Private Link 構成
    privateLinkConfigurations: [
      {
        name: privateLinkConfigName
        properties: {
          ipConfigurations: [
            {
              name: 'privateLinkIpConfig'
              properties: {
                privateIPAllocationMethod: 'Dynamic'
                subnet: {
                  id: appGwSubnetId
                }
              }
            }
          ]
        }
      }
    ]
    webApplicationFirewallConfiguration: {
      enabled: true
      firewallMode: 'Detection'
      ruleSetType: 'OWASP'
      ruleSetVersion: '3.2'
    }
  }
}

// 出力
output appGwId string = applicationGateway.id
output appGwName string = applicationGateway.name
output appGwPublicIp string = publicIp.properties.ipAddress
output appGwPrivateIp string = applicationGateway.properties.frontendIPConfigurations[1].properties.privateIPAddress
output privateLinkConfigurationId string = '${applicationGateway.id}/privateLinkConfigurations/${privateLinkConfigName}'
