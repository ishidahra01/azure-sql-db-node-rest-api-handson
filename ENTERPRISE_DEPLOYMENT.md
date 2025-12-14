# 🏢 本格的な構成のデプロイガイド

このガイドでは、本番レベルのセキュアな Azure PaaS アーキテクチャをデプロイする手順を説明します。

## 📐 アーキテクチャ概要

```
[Internet]
    ↓ HTTPS (Azure Front Door 既定ドメイン)
[Azure Front Door Premium]
    ↓ Private Link (Front Door Premium 必須)
[Application Gateway (WAF v2)]
    - Private frontend IP: 実際の着地点
    - Public frontend IP: 仕様上の存在要件（基本未使用）
    - TLS 終端 (証明書管理)
    ↓ HTTP (VNet内部、証明書運用の簡素化)
[Azure Firewall Premium (IDPS有効)]
    ↓ HTTP
[API Management Premium (Internal VNet)]
    ↓ Private Endpoint
[Azure Functions Premium (VNet統合)]
    ↓ Private Endpoint (TDS + TLS)
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
- Internet → Front Door: **HTTPS** (Azure Front Door 既定ドメイン)
- Front Door → Application Gateway: **HTTP** (Private Link トンネル経由)
- Application Gateway (TLS 終端): **HTTP** (VNet内部)
- Firewall → API Management: **HTTP** (VNet内部)
- API Management → Functions: **HTTPS** (Private Endpoint経由)
- Functions → SQL Database: **TDS + TLS** (必須、Private Endpoint経由)

> **重要な設計判断**:
> - **Front Door → AppGW を Private Link にする理由**: インターネット露出を最小化、Azure バックボーン経由の閉域接続
> - **AppGW が Public + Private IP を持つ理由**: Private Link 機能のための仕様上の要件。Public IP は実運用では未使用
> - **Application Gateway で TLS 終端する理由**: 証明書管理を一箇所に集約、内部は HTTP で簡素化
> - **VNet 内部を HTTP にする理由**: 証明書運用の複雑さを回避、Azure のネットワーク分離で保護

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

## 🔐 証明書の準備（オプション）

Application Gateway で TLS 終端を行う場合、証明書が必要です。

### 証明書の取得方法

**方法 1: App Service Certificate を使用（推奨）**

App Service Certificate は Azure が管理する証明書で、自動更新が可能です。

1. Azure Portal で "App Service Certificates" を検索
2. 新しい証明書を作成
   - ドメイン名を指定（例: `api.example.com`）
   - 証明書の検証（DNS または HTTP）
3. Key Vault にエクスポート
4. 証明書を Base64 エンコードして Bicep パラメータに設定

**方法 2: 自己署名証明書（開発環境のみ）**

```bash
# OpenSSL で自己署名証明書を作成
openssl req -x509 -newkey rsa:4096 -keyout appgw-key.pem -out appgw-cert.pem -days 365 -nodes

# PFX 形式に変換
openssl pkcs12 -export -out appgw-cert.pfx -inkey appgw-key.pem -in appgw-cert.pem -password pass:YourPassword123

# Base64 エンコード
base64 -i appgw-cert.pfx -o appgw-cert.b64
```

**方法 3: Azure Front Door の既定ドメインを使用（証明書不要）**

証明書を設定しない場合:
- Front Door の既定ドメイン（`*.azurefd.net`）で HTTPS 終端
- Front Door → AppGW は HTTP（Private Link トンネル経由）
- AppGW も HTTP で動作（証明書不要）

### 証明書パラメータの設定

証明書を使用する場合、パラメータファイルに以下を追加:

```json
{
  "tlsCertificateData": {
    "value": "<Base64エンコードされた証明書データ>"
  },
  "tlsCertificatePassword": {
    "value": "<証明書のパスワード>"
  }
}
```

> **注意**: 本番環境では、証明書を Key Vault に保存し、Bicep から参照することを推奨します。

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

### Step 9: Private Link 接続の承認

デプロイ後、Front Door からの Private Link 接続要求を承認する必要があります。

```bash
# Azure Portal での承認手順:
# 1. Application Gateway のリソースを開く
# 2. 左メニューから "Settings" → "Private Link" を選択
# 3. "Private endpoint connections" タブを開く
# 4. Front Door からの接続要求（Status: Pending）を選択
# 5. "Approve" をクリック

# または Azure CLI で承認:
az network application-gateway private-link approve \
  --resource-group rg-handson-prod \
  --gateway-name appgw-handson-prod \
  --name <private-endpoint-connection-name>
```

> **重要**: Private Link 接続が承認されるまで、Front Door から Application Gateway への接続は確立されません。

## ✅ 動作確認

### Step 10: エンドポイントのテスト

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

A5: エンタープライズ構成では推奨します。Private Link により以下のメリットがあります:
- インターネット露出の最小化（Front Door のみが公開エンドポイント）
- Azure バックボーンネットワーク経由の閉域接続
- Application Gateway のパブリック IP は仕様上存在するが実運用では未使用
- より厳格なセキュリティ要件に対応

**Q6: Application Gateway が Public + Private IP を持つのはなぜですか？**

A6: これは Private Link 機能のための Azure の仕様です:
- Private Link をサポートするには、両方のフロントエンド IP が必要
- Private IP: Front Door からの実際の着地点
- Public IP: Private Link 機能のための技術的要件（基本未使用）
- Private IP のみの構成では Private Link をサポートしません

**Q7: 証明書がない場合はどうなりますか？**

A7: 証明書パラメータを空にした場合:
- Front Door が HTTPS 終端（`*.azurefd.net` ドメイン）
- Front Door → AppGW は HTTP（Private Link トンネル経由）
- AppGW も HTTP で動作
- カスタムドメインは使用不可ですが、開発環境では十分

**Q8: Private Link 接続の承認を忘れた場合は？**

A8: Front Door からのトラフィックが Application Gateway に到達しません:
- Front Door のヘルスチェックが失敗
- API リクエストがタイムアウト
- Azure Portal の AppGW → Private Link で接続要求を確認し承認してください

---

## 📝 フィードバック

このガイドに関するフィードバックや改善提案は、GitHub Issues でお知らせください。
