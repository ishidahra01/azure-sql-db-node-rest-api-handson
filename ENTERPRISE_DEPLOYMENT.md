# 🏢 本格的な構成のデプロイガイド

このガイドでは、本番レベルのセキュアな Azure PaaS アーキテクチャをデプロイする手順を説明します。

## 📐 アーキテクチャ概要

```
[Internet]
    ↓ HTTPS
[Azure Front Door Premium]
    ↓ Private Endpoint
[Application Gateway (WAF v2)]
    ↓ HTTP (証明書管理の簡略化のため)
[Azure Firewall Premium (IDPS有効)]
    ↓ HTTP
[API Management Premium (Internal VNet)]
    ↓ Private Endpoint
[Azure Functions Premium (VNet統合)]
    ↓ Private Endpoint
[Azure SQL Database (Private Endpoint)]
```

## 🔐 セキュリティ設計

### プライベート接続の実装
- **SQL Database**: パブリックアクセス無効、Private Endpoint のみ
- **Functions**: パブリックアクセス無効、Private Endpoint のみ
- **API Management**: Internal VNet モード
- **Front Door**: Application Gateway への Private Link 接続

### ファイアウォールとセキュリティ
- **Azure Firewall**: Premium SKU で IDPS (侵入検知・防止システム) 有効
- **Application Gateway**: WAF v2 で OWASP ルールセット適用
- **Front Door**: グローバルなエントリポイントとして DDoS 保護

### 通信プロトコル
- Internet → Front Door: **HTTPS**
- Front Door → Application Gateway: **HTTP** (Private Link経由)
- Application Gateway → Firewall: **HTTP** (VNet内部)
- Firewall → API Management: **HTTP** (VNet内部)
- API Management → Functions: **HTTPS** (Private Endpoint経由)
- Functions → SQL Database: **TLS暗号化** (Private Endpoint経由)

> **注**: Application Gateway 以降を HTTP にすることで、証明書管理の複雑さを回避しています。
> VNet 内部の通信は Azure のネットワーク分離により保護されます。

## 🛠️ 前提条件

### 必須ツール
- Azure CLI (`az --version` で確認)
- Bicep CLI (Azure CLI 2.20.0+ に含まれる)
- Azure Functions Core Tools v4
- Node.js 18 以上

### Azure サブスクリプション要件
- **サブスクリプション所有者または共同作成者ロール**が必要
- **十分なリソースクォータ**:
  - Azure Firewall Premium
  - API Management Premium
  - Azure Front Door Premium

### 推定コスト
- **月額 約 $4,000-5,000** (Japan East リージョン)
  - Azure Front Door Premium: ~$330
  - API Management Premium: ~$3,000
  - Azure Firewall Premium: ~$900
  - Functions Premium EP1: ~$150
  - SQL Database Basic: ~$5
  - その他 (Storage, App Insights): ~$10

> **重要**: このアーキテクチャは本番環境向けです。学習目的の場合は `main.bicep` (簡易版) を使用してください。

## 📋 デプロイ手順

### Step 1: パラメータファイルの準備

```bash
# テンプレートをコピー
cp main-enterprise.parameters.json.template main-enterprise.parameters.json

# エディタで編集
vim main-enterprise.parameters.json
```

**編集する値**:
```json
{
  "sqlAdminPassword": {
    "value": "YourStrongP@ssw0rd123!"  // 強力なパスワードを設定
  },
  "apimPublisherEmail": {
    "value": "your-email@example.com"  // 実際のメールアドレス
  },
  "apimPublisherName": {
    "value": "Your Organization Name"  // 組織名
  }
}
```

### Step 2: Azure にログイン

```bash
# Azure にログイン
az login

# サブスクリプションの確認
az account show

# 必要に応じてサブスクリプションを切り替え
az account set --subscription "YOUR_SUBSCRIPTION_ID"
```

### Step 3: リソースグループの作成

```bash
# リソースグループを作成
az group create \
  --name rg-handson-prod \
  --location japaneast
```

### Step 4: Bicep テンプレートの検証

```bash
# 構文チェック
az bicep build --file main-enterprise.bicep

# What-If 分析（デプロイせずに変更を確認）
az deployment group what-if \
  --resource-group rg-handson-prod \
  --template-file main-enterprise.bicep \
  --parameters main-enterprise.parameters.json
```

### Step 5: デプロイの実行

```bash
# デプロイを開始
az deployment group create \
  --resource-group rg-handson-prod \
  --template-file main-enterprise.bicep \
  --parameters main-enterprise.parameters.json \
  --mode Incremental
```

> **所要時間**: 60〜90 分  
> - ネットワークリソース: 5-10 分
> - Azure Firewall: 10-15 分
> - Application Gateway: 10-15 分
> - API Management Premium: 30-45 分
> - Azure Front Door: 10-15 分
> - Functions, SQL: 5-10 分

### Step 6: デプロイ結果の確認

```bash
# デプロイ出力を確認
az deployment group show \
  --resource-group rg-handson-prod \
  --name main-enterprise \
  --query properties.outputs
```

出力例:
```json
{
  "frontDoorEndpointUrl": "https://ep-handson-prod-xyz.azurefd.net",
  "appGwPublicIp": "20.xxx.xxx.xxx",
  "functionAppName": "func-handson-prod",
  "sqlServerName": "sql-handson-prod-abc123",
  "apimName": "apim-handson-prod"
}
```

## 🗄️ データベースのセットアップ

### Step 7: SQL スクリプトの実行

デプロイ後、SQL Database にスキーマとデータを投入します。

**方法 1: Azure Portal を使用**

1. Azure Portal で SQL Database を開く
2. 左メニューから **Query editor (preview)** を選択
3. SQL 認証情報でログイン
   - ユーザー名: `sqladmin`
   - パスワード: パラメータで指定したもの
4. `sql/HandsOnSetup.sql` の内容をコピー&ペースト
5. **Run** をクリックして実行

**方法 2: Azure Data Studio を使用**

```bash
# Azure Data Studio をインストール（まだの場合）
# https://aka.ms/azuredatastudio

# 接続情報
# Server: sql-handson-prod-abc123.database.windows.net
# Database: sqldb-handson-prod
# Authentication: SQL Login
# Username: sqladmin
# Password: (パラメータで指定したもの)
```

**実行するスクリプト**:
```sql
-- sql/HandsOnSetup.sql の内容
-- Customers テーブル、ストアドプロシージャ、サンプルデータが作成されます
```

## 📦 Functions コードのデプロイ

### Step 8: Functions にコードをデプロイ

```bash
# リポジトリのルートディレクトリで実行
cd /path/to/azure-sql-db-node-rest-api-handson

# 依存パッケージをインストール（まだの場合）
npm install

# Functions にデプロイ
func azure functionapp publish func-handson-prod

# または deploy-function-code.sh を使用
./deploy-function-code.sh func-handson-prod
```

デプロイが完了すると、以下のように表示されます:
```
Deployment successful.
Remote build succeeded!
Syncing triggers...
Functions in func-handson-prod:
    customer - [httpTrigger]
        Invoke url: https://func-handson-prod.azurewebsites.net/api/customer/{id}
```

## ✅ 動作確認

### Step 9: エンドポイントのテスト

**1. Front Door 経由でアクセス（推奨）**

```bash
# Front Door のエンドポイント URL を取得
FRONTDOOR_URL=$(az deployment group show \
  --resource-group rg-handson-prod \
  --name main-enterprise \
  --query properties.outputs.frontDoorEndpointUrl.value -o tsv)

# API をテスト
curl "${FRONTDOOR_URL}/api/customer/123"
```

**2. Application Gateway 経由でアクセス**

```bash
# Application Gateway のパブリック IP を取得
APPGW_IP=$(az deployment group show \
  --resource-group rg-handson-prod \
  --name main-enterprise \
  --query properties.outputs.appGwPublicIp.value -o tsv)

# API をテスト
curl "http://${APPGW_IP}/api/customer/123"
```

**期待されるレスポンス**:
```json
[
  {
    "CustomerID": 123,
    "CustomerName": "Tailspin Toys (Roe Park, NY)",
    "PhoneNumber": "(212) 555-0100",
    "WebsiteURL": "http://www.tailspintoys.com/RoePark",
    "AddressLine1": "Shop 219",
    "AddressLine2": "528 Persson Road",
    "PostalCode": "90775"
  }
]
```

## 🔍 トラブルシューティング

### デプロイエラー

**1. API Management のデプロイに失敗**
```
Error: Resource Microsoft.ApiManagement/service 'apim-handson-prod' 
       already exists in another resource group
```
**解決策**: パラメータファイルの `projectName` を変更して別の名前を使用

**2. クォータ不足エラー**
```
Error: The subscription is not registered to use namespace 
       'Microsoft.Network/azureFirewalls'
```
**解決策**: リソースプロバイダーを登録
```bash
az provider register --namespace Microsoft.Network
az provider show --namespace Microsoft.Network --query "registrationState"
```

**3. パスワードポリシーエラー**
```
Error: Password does not meet complexity requirements
```
**解決策**: SQL パスワードは以下の要件を満たす必要があります:
- 8 文字以上
- 大文字、小文字、数字、特殊文字を含む
- ユーザー名の一部を含まない

### 接続エラー

**1. Front Door から Application Gateway に接続できない**

```bash
# Application Gateway の正常性を確認
az network application-gateway show-backend-health \
  --resource-group rg-handson-prod \
  --name appgw-handson-prod
```

**2. Functions が SQL に接続できない**

```bash
# Functions のログを確認
func azure functionapp logstream func-handson-prod --browser

# または Azure Portal で
# Function App → Monitoring → Log stream
```

**3. Private Endpoint の DNS 解決**

```bash
# Private DNS Zone が正しく設定されているか確認
az network private-dns zone list \
  --resource-group rg-handson-prod \
  --query "[].name" -o table
```

### パフォーマンスの問題

**1. レスポンスが遅い**
- Azure Front Door のキャッシュを有効化
- API Management のレスポンスキャッシュポリシーを追加
- Functions のインスタンス数を増やす

**2. SQL Database のパフォーマンス**
- Basic SKU から Standard 以上にアップグレード
- クエリのインデックスを最適化

## 📊 監視とログ

### Application Insights でのモニタリング

```bash
# Application Insights のダッシュボードを開く
az portal application-insights show \
  --resource-group rg-handson-prod \
  --name appi-handson-prod
```

**確認できる情報**:
- API のレスポンスタイム
- エラー率
- 依存関係のパフォーマンス
- SQL クエリの実行時間

### Azure Firewall のログ

```bash
# Firewall のログを確認
az monitor diagnostic-settings create \
  --resource $(az network firewall show -g rg-handson-prod -n afw-handson-prod --query id -o tsv) \
  --name firewall-logs \
  --logs '[{"category": "AzureFirewallApplicationRule", "enabled": true}]' \
  --workspace $(az monitor log-analytics workspace show -g rg-handson-prod -n law-handson-prod --query id -o tsv)
```

## 🧹 クリーンアップ

リソースが不要になったら、リソースグループごと削除します:

```bash
# 削除前の確認
az group show --name rg-handson-prod

# リソースグループを削除（すべてのリソースが削除されます）
az group delete --name rg-handson-prod --yes --no-wait
```

> **注意**: この操作は取り消せません。削除前に必要なデータをバックアップしてください。

## 📚 次のステップ

### セキュリティの強化
- [ ] Azure Key Vault で機密情報を管理
- [ ] Managed Identity を使用した認証
- [ ] APIM のサブスクリプションキー管理
- [ ] Front Door の WAF カスタムルール追加

### 可用性の向上
- [ ] マルチリージョンデプロイ
- [ ] SQL Database のフェイルオーバーグループ
- [ ] Functions の自動スケーリング設定

### 運用の改善
- [ ] Azure DevOps / GitHub Actions で CI/CD パイプライン構築
- [ ] アラートとアクションの設定
- [ ] バックアップとディザスタリカバリプラン

## 🔗 参考リンク

- [Azure Front Door のドキュメント](https://learn.microsoft.com/ja-jp/azure/frontdoor/)
- [Application Gateway のドキュメント](https://learn.microsoft.com/ja-jp/azure/application-gateway/)
- [Azure Firewall Premium のドキュメント](https://learn.microsoft.com/ja-jp/azure/firewall/premium-features)
- [API Management の VNet 統合](https://learn.microsoft.com/ja-jp/azure/api-management/api-management-using-with-vnet)
- [Azure Functions の VNet 統合](https://learn.microsoft.com/ja-jp/azure/azure-functions/functions-networking-options)
- [Azure SQL の Private Link](https://learn.microsoft.com/ja-jp/azure/azure-sql/database/private-endpoint-overview)

---

## ❓ よくある質問

**Q1: なぜ Application Gateway 以降を HTTP にするのですか？**

A1: 証明書管理の複雑さを回避するためです。VNet 内部の通信は Azure のネットワーク分離により保護されており、外部からアクセスできません。Front Door で HTTPS 終端することで、クライアントからの通信は暗号化されています。

**Q2: API Management の Developer SKU は使えませんか？**

A2: Developer SKU では VNet 統合ができません。Internal VNet モードを使用するには Premium SKU が必要です。

**Q3: Functions の消費プランは使えませんか？**

A3: 消費プランでは VNet 統合ができません。VNet 統合には Premium プラン (Elastic Premium) が必要です。

**Q4: Private Endpoint のコストはいくらですか？**

A4: Private Endpoint 自体は月額 ~$8 ですが、データ転送料金が別途かかります。詳細は [Azure Pricing Calculator](https://azure.microsoft.com/ja-jp/pricing/calculator/) で確認してください。

**Q5: Front Door の Private Link 接続は本当に必要ですか？**

A5: セキュリティ要件によります。このテンプレートでは Application Gateway のパブリック IP を使用していますが、より厳格なセキュリティが必要な場合は Private Link Origin を使用できます。

---

## 📝 フィードバック

このガイドに関するフィードバックや改善提案は、GitHub Issues でお知らせください。
