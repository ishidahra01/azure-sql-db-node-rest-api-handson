# Bicep モジュール

このディレクトリには、エンタープライズ構成をデプロイするための Bicep モジュールが含まれています。

## 📁 モジュール一覧

### 1. network.bicep
**説明**: Virtual Network とサブネット構成

**作成するリソース**:
- Virtual Network (10.0.0.0/16)
- 5つのサブネット:
  - ApplicationGatewaySubnet (10.0.1.0/24)
  - AzureFirewallSubnet (10.0.2.0/24)
  - ApiManagementSubnet (10.0.3.0/24)
  - FunctionsSubnet (10.0.4.0/24)
  - PrivateEndpointSubnet (10.0.5.0/24)
- Network Security Groups (5個)

**パラメータ**:
- `location`: デプロイ先のリージョン
- `env`: 環境識別子
- `projectName`: プロジェクト名

**出力**:
- `vnetId`: VNet リソース ID
- `vnetName`: VNet 名
- `appGwSubnetId`: Application Gateway サブネット ID
- `firewallSubnetId`: Firewall サブネット ID
- `apimSubnetId`: API Management サブネット ID
- `functionsSubnetId`: Functions サブネット ID
- `privateEndpointSubnetId`: Private Endpoint サブネット ID

---

### 2. firewall.bicep
**説明**: Azure Firewall Premium with IDPS

**作成するリソース**:
- Azure Firewall Premium
- Firewall Policy (IDPS有効)
- Public IP Address
- Application Rule Collection

**パラメータ**:
- `location`: デプロイ先のリージョン
- `env`: 環境識別子
- `projectName`: プロジェクト名
- `firewallSubnetId`: Firewall サブネット ID

**出力**:
- `firewallId`: Firewall リソース ID
- `firewallName`: Firewall 名
- `firewallPrivateIp`: Firewall プライベート IP
- `firewallPublicIp`: Firewall パブリック IP

**特徴**:
- Premium SKU（IDPS対応）
- 侵入検知・防止モード: Alert
- DNS Proxy 有効

---

### 3. appgw.bicep
**説明**: Application Gateway WAF v2

**作成するリソース**:
- Application Gateway WAF v2
- Public IP Address
- WAF Configuration (OWASP 3.2)

**パラメータ**:
- `location`: デプロイ先のリージョン
- `env`: 環境識別子
- `projectName`: プロジェクト名
- `appGwSubnetId`: Application Gateway サブネット ID
- `backendIpAddress`: バックエンド (Firewall) IP

**出力**:
- `appGwId`: Application Gateway リソース ID
- `appGwName`: Application Gateway 名
- `appGwPublicIp`: Application Gateway パブリック IP

**特徴**:
- WAF v2 SKU
- OWASP 3.2 ルールセット
- Detection モード
- HTTP → Firewall への転送

---

### 4. apim.bicep
**説明**: API Management Premium (Internal VNet)

**作成するリソース**:
- API Management Premium
- Customer API 定義
- GET /customer/{id} オペレーション
- Functions へのバックエンドポリシー

**パラメータ**:
- `location`: デプロイ先のリージョン
- `env`: 環境識別子
- `projectName`: プロジェクト名
- `apimSubnetId`: API Management サブネット ID
- `apimPublisherEmail`: 管理者メールアドレス
- `apimPublisherName`: 組織名
- `functionAppHostName`: Functions ホスト名

**出力**:
- `apimId`: APIM リソース ID
- `apimName`: APIM 名
- `apimPrivateIp`: APIM プライベート IP
- `apimGatewayUrl`: APIM ゲートウェイ URL

**特徴**:
- Premium SKU（VNet統合に必要）
- Internal VNet モード
- システム割り当てマネージド ID
- サブスクリプションキー不要（開発用）

---

### 5. functions.bicep
**説明**: Azure Functions Premium with VNet 統合

**作成するリソース**:
- App Service Plan (Premium EP1)
- Function App
- Private Endpoint
- Private DNS Zone (privatelink.azurewebsites.net)
- Private DNS Zone Group

**パラメータ**:
- `location`: デプロイ先のリージョン
- `env`: 環境識別子
- `projectName`: プロジェクト名
- `functionsSubnetId`: Functions サブネット ID
- `privateEndpointSubnetId`: Private Endpoint サブネット ID
- `sqlServerFqdn`: SQL Server FQDN
- `sqlDatabaseName`: SQL Database 名
- `sqlAdminUsername`: SQL 管理者ユーザー名
- `sqlAdminPassword`: SQL 管理者パスワード（secure）
- `appInsightsInstrumentationKey`: Application Insights キー
- `storageAccountConnectionString`: Storage Account 接続文字列（secure）

**出力**:
- `functionAppId`: Functions リソース ID
- `functionAppName`: Functions 名
- `functionAppHostName`: Functions ホスト名
- `privateEndpointIp`: Private Endpoint IP

**特徴**:
- ElasticPremium EP1 プラン
- VNet 統合（アウトバウンド）
- Private Endpoint（インバウンド）
- パブリックアクセス無効
- Node.js 18 ランタイム

---

### 6. sqldb.bicep
**説明**: Azure SQL Database with Private Endpoint

**作成するリソース**:
- SQL Server
- SQL Database
- Private Endpoint
- Private DNS Zone (privatelink.database.windows.net)
- Private DNS Zone Group

**パラメータ**:
- `location`: デプロイ先のリージョン
- `env`: 環境識別子
- `projectName`: プロジェクト名
- `privateEndpointSubnetId`: Private Endpoint サブネット ID
- `sqlAdminUsername`: SQL 管理者ユーザー名
- `sqlAdminPassword`: SQL 管理者パスワード（secure）

**出力**:
- `sqlServerId`: SQL Server リソース ID
- `sqlServerName`: SQL Server 名
- `sqlServerFqdn`: SQL Server FQDN
- `sqlDatabaseName`: SQL Database 名
- `privateEndpointIp`: Private Endpoint IP

**特徴**:
- SQL Server 12.0
- パブリックアクセス完全無効
- Private Endpoint のみでアクセス
- TLS 1.2 強制
- Basic SKU（開発用、本番は Standard 以上推奨）

---

### 7. frontdoor.bicep
**説明**: Azure Front Door Premium

**作成するリソース**:
- Front Door Profile
- Front Door Endpoint
- Origin Group
- Origin (Application Gateway)
- Route

**パラメータ**:
- `env`: 環境識別子
- `projectName`: プロジェクト名
- `appGwPublicIp`: Application Gateway パブリック IP

**出力**:
- `frontDoorId`: Front Door リソース ID
- `frontDoorName`: Front Door 名
- `frontDoorEndpointUrl`: Front Door エンドポイント URL
- `frontDoorEndpointHostName`: Front Door ホスト名

**特徴**:
- Premium SKU
- グローバルロケーション
- HTTP Only 転送（Application Gateway への接続）
- ヘルスプローブ有効

---

## 🔄 依存関係

```
network.bicep
├─ firewall.bicep
│  └─ appgw.bicep
│     └─ frontdoor.bicep
├─ sqldb.bicep
│  └─ functions.bicep
│     └─ apim.bicep
└─ (各モジュールは network に依存)
```

**デプロイ順序**:
1. network.bicep
2. firewall.bicep + sqldb.bicep (並列可能)
3. appgw.bicep + functions.bicep (並列可能)
4. apim.bicep
5. frontdoor.bicep

> **注**: main-enterprise.bicep では、Bicep が自動的に依存関係を解決するため、明示的な `dependsOn` は不要です。

---

## 🛠️ 使用方法

### 個別モジュールのテスト

各モジュールは独立してテストできます:

```bash
# 構文チェック
az bicep build --file modules/network.bicep

# デプロイ（パラメータを直接指定）
az deployment group create \
  --resource-group rg-test \
  --template-file modules/network.bicep \
  --parameters location=japaneast env=dev projectName=test
```

### メインテンプレートからの使用

通常は `main-enterprise.bicep` から使用します:

```bicep
module network 'modules/network.bicep' = {
  name: 'networkDeployment'
  params: {
    location: location
    env: env
    projectName: projectName
  }
}
```

---

## 📝 ベストプラクティス

### パラメータ
- ✅ すべてのパラメータに `@description()` を付与
- ✅ 機密情報には `@secure()` を使用
- ✅ デフォルト値は設定せず、親から渡す

### 出力
- ✅ 他のモジュールが必要とする情報を出力
- ✅ リソース ID、名前、FQDN など
- ✅ プライベート IP アドレス

### リソース命名
- ✅ ネーミング規則に従う（bicep.instructions.md 参照）
- ✅ `uniqueString()` で重複回避
- ✅ 環境とプロジェクト名を含める

---

## 🔍 トラブルシューティング

### デプロイエラー

**エラー**: `The subnet 'ApiManagementSubnet' is not delegated to 'Microsoft.ApiManagement/service'`

**解決策**: network.bicep で delegation が正しく設定されているか確認

**エラー**: `Cannot create more than 1 private endpoint for resource`

**解決策**: 既存の Private Endpoint を削除してから再デプロイ

### 検証エラー

**警告**: `no-unused-params: Parameter 'xxx' is declared but never used`

**解決策**: 未使用のパラメータを削除

**警告**: `no-unnecessary-dependson: Remove unnecessary dependsOn entry`

**解決策**: Bicep が自動解決する依存関係を削除

---

## 📚 参考リンク

- [Bicep ドキュメント](https://learn.microsoft.com/ja-jp/azure/azure-resource-manager/bicep/)
- [Azure リソースの命名規則](https://learn.microsoft.com/ja-jp/azure/cloud-adoption-framework/ready/azure-best-practices/resource-naming)
- [Bicep モジュール](https://learn.microsoft.com/ja-jp/azure/azure-resource-manager/bicep/modules)
- [Private Endpoint](https://learn.microsoft.com/ja-jp/azure/private-link/private-endpoint-overview)

---

## 🤝 コントリビューション

モジュールの改善提案は、GitHub Issues または Pull Request でお願いします。

- バグ報告
- 機能追加の提案
- ドキュメントの改善
- コードレビュー

---

このモジュールは、エンタープライズグレードのAzureアーキテクチャを実装するための、再利用可能で保守しやすいコンポーネントです。
