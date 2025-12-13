// ネットワークモジュール: VNet とサブネット構成
@description('デプロイ先のリージョン')
param location string

@description('環境識別子')
param env string

@description('プロジェクト名')
param projectName string

// 変数
var vnetName = 'vnet-${projectName}-${env}'
var nsgNameAppGw = 'nsg-appgw-${projectName}-${env}'
var nsgNameFirewall = 'nsg-firewall-${projectName}-${env}'
var nsgNameApim = 'nsg-apim-${projectName}-${env}'
var nsgNameFunctions = 'nsg-functions-${projectName}-${env}'
var nsgNamePrivateEndpoint = 'nsg-pe-${projectName}-${env}'

// VNet アドレス空間
var vnetAddressPrefix = '10.0.0.0/16'
var appGwSubnetPrefix = '10.0.1.0/24'
var firewallSubnetPrefix = '10.0.2.0/24'
var apimSubnetPrefix = '10.0.3.0/24'
var functionsSubnetPrefix = '10.0.4.0/24'
var privateEndpointSubnetPrefix = '10.0.5.0/24'

// NSG for Application Gateway
resource nsgAppGw 'Microsoft.Network/networkSecurityGroups@2023-05-01' = {
  name: nsgNameAppGw
  location: location
  properties: {
    securityRules: [
      {
        name: 'AllowGatewayManager'
        properties: {
          priority: 100
          protocol: 'Tcp'
          access: 'Allow'
          direction: 'Inbound'
          sourceAddressPrefix: 'GatewayManager'
          sourcePortRange: '*'
          destinationAddressPrefix: '*'
          destinationPortRange: '65200-65535'
        }
      }
      {
        name: 'AllowHTTPS'
        properties: {
          priority: 110
          protocol: 'Tcp'
          access: 'Allow'
          direction: 'Inbound'
          sourceAddressPrefix: 'Internet'
          sourcePortRange: '*'
          destinationAddressPrefix: '*'
          destinationPortRange: '443'
        }
      }
      {
        name: 'AllowAzureLoadBalancer'
        properties: {
          priority: 120
          protocol: '*'
          access: 'Allow'
          direction: 'Inbound'
          sourceAddressPrefix: 'AzureLoadBalancer'
          sourcePortRange: '*'
          destinationAddressPrefix: '*'
          destinationPortRange: '*'
        }
      }
    ]
  }
}

// NSG for Azure Firewall
resource nsgFirewall 'Microsoft.Network/networkSecurityGroups@2023-05-01' = {
  name: nsgNameFirewall
  location: location
  properties: {
    securityRules: []
  }
}

// NSG for API Management
resource nsgApim 'Microsoft.Network/networkSecurityGroups@2023-05-01' = {
  name: nsgNameApim
  location: location
  properties: {
    securityRules: [
      {
        name: 'AllowManagementEndpoint'
        properties: {
          priority: 100
          protocol: 'Tcp'
          access: 'Allow'
          direction: 'Inbound'
          sourceAddressPrefix: 'ApiManagement'
          sourcePortRange: '*'
          destinationAddressPrefix: 'VirtualNetwork'
          destinationPortRange: '3443'
        }
      }
      {
        name: 'AllowHTTPSInbound'
        properties: {
          priority: 110
          protocol: 'Tcp'
          access: 'Allow'
          direction: 'Inbound'
          sourceAddressPrefix: 'VirtualNetwork'
          sourcePortRange: '*'
          destinationAddressPrefix: 'VirtualNetwork'
          destinationPortRange: '443'
        }
      }
      {
        name: 'AllowHTTPInbound'
        properties: {
          priority: 120
          protocol: 'Tcp'
          access: 'Allow'
          direction: 'Inbound'
          sourceAddressPrefix: 'VirtualNetwork'
          sourcePortRange: '*'
          destinationAddressPrefix: 'VirtualNetwork'
          destinationPortRange: '80'
        }
      }
      {
        name: 'AllowAzureLoadBalancer'
        properties: {
          priority: 130
          protocol: '*'
          access: 'Allow'
          direction: 'Inbound'
          sourceAddressPrefix: 'AzureLoadBalancer'
          sourcePortRange: '*'
          destinationAddressPrefix: '*'
          destinationPortRange: '*'
        }
      }
    ]
  }
}

// NSG for Functions
resource nsgFunctions 'Microsoft.Network/networkSecurityGroups@2023-05-01' = {
  name: nsgNameFunctions
  location: location
  properties: {
    securityRules: []
  }
}

// NSG for Private Endpoints
resource nsgPrivateEndpoint 'Microsoft.Network/networkSecurityGroups@2023-05-01' = {
  name: nsgNamePrivateEndpoint
  location: location
  properties: {
    securityRules: []
  }
}

// Virtual Network
resource vnet 'Microsoft.Network/virtualNetworks@2023-05-01' = {
  name: vnetName
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: [
        vnetAddressPrefix
      ]
    }
    subnets: [
      {
        name: 'ApplicationGatewaySubnet'
        properties: {
          addressPrefix: appGwSubnetPrefix
          networkSecurityGroup: {
            id: nsgAppGw.id
          }
        }
      }
      {
        name: 'AzureFirewallSubnet'
        properties: {
          addressPrefix: firewallSubnetPrefix
          networkSecurityGroup: {
            id: nsgFirewall.id
          }
        }
      }
      {
        name: 'ApiManagementSubnet'
        properties: {
          addressPrefix: apimSubnetPrefix
          networkSecurityGroup: {
            id: nsgApim.id
          }
          delegations: [
            {
              name: 'apim-delegation'
              properties: {
                serviceName: 'Microsoft.ApiManagement/service'
              }
            }
          ]
        }
      }
      {
        name: 'FunctionsSubnet'
        properties: {
          addressPrefix: functionsSubnetPrefix
          networkSecurityGroup: {
            id: nsgFunctions.id
          }
          delegations: [
            {
              name: 'functions-delegation'
              properties: {
                serviceName: 'Microsoft.Web/serverFarms'
              }
            }
          ]
        }
      }
      {
        name: 'PrivateEndpointSubnet'
        properties: {
          addressPrefix: privateEndpointSubnetPrefix
          networkSecurityGroup: {
            id: nsgPrivateEndpoint.id
          }
          privateEndpointNetworkPolicies: 'Disabled'
        }
      }
    ]
  }
}

// 出力
output vnetId string = vnet.id
output vnetName string = vnet.name
output appGwSubnetId string = '${vnet.id}/subnets/ApplicationGatewaySubnet'
output firewallSubnetId string = '${vnet.id}/subnets/AzureFirewallSubnet'
output apimSubnetId string = '${vnet.id}/subnets/ApiManagementSubnet'
output functionsSubnetId string = '${vnet.id}/subnets/FunctionsSubnet'
output privateEndpointSubnetId string = '${vnet.id}/subnets/PrivateEndpointSubnet'
