// Azure SQL Database モジュール: Private Endpoint
@description('デプロイ先のリージョン')
param location string

@description('環境識別子')
param env string

@description('プロジェクト名')
param projectName string

@description('Private Endpoint サブネット ID')
param privateEndpointSubnetId string

@description('SQL 管理者ユーザー名')
param sqlAdminUsername string

@description('SQL 管理者パスワード')
@secure()
param sqlAdminPassword string

// 変数
var uniqueId = uniqueString(resourceGroup().id)
var sqlServerName = 'sql-${projectName}-${env}-${take(uniqueId, 6)}'
var sqlDatabaseName = 'sqldb-${projectName}-${env}'
var privateEndpointName = 'pe-sql-${projectName}-${env}'
var privateDnsZoneName = 'privatelink${environment().suffixes.sqlServerHostname}'

// SQL Server
resource sqlServer 'Microsoft.Sql/servers@2022-05-01-preview' = {
  name: sqlServerName
  location: location
  properties: {
    administratorLogin: sqlAdminUsername
    administratorLoginPassword: sqlAdminPassword
    version: '12.0'
    minimalTlsVersion: '1.2'
    publicNetworkAccess: 'Disabled'
    restrictOutboundNetworkAccess: 'Disabled'
  }
  tags: {
    SecurityControl: 'Ignore'
  }
}

// SQL Database
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

// Private DNS Zone for SQL
resource privateDnsZone 'Microsoft.Network/privateDnsZones@2020-06-01' = {
  name: privateDnsZoneName
  location: 'global'
}

// Private Endpoint for SQL
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
          privateLinkServiceId: sqlServer.id
          groupIds: [
            'sqlServer'
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
output sqlServerId string = sqlServer.id
output sqlServerName string = sqlServer.name
output sqlServerFqdn string = '${sqlServer.name}${environment().suffixes.sqlServerHostname}'
output sqlDatabaseName string = sqlDatabase.name
output privateEndpointIp string = privateEndpoint.properties.customDnsConfigs[0].ipAddresses[0]
