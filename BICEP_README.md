# 🏗️ Bicep を使った本番構成のデプロイ（パス3）

> **このドキュメントの対象者**: 本番レベルのアーキテクチャを構築したい方  
> **前提条件**: [標準ハンズオン（パス2）](README.md)を完了していること  
> **所要時間**: 1-3時間（Azure リソースのプロビジョニングに時間がかかります）  
> **ゴール**: Front Door → APIM → Functions → SQL という本番構成を IaC でデプロイ

このディレクトリには、Azure リソースを宣言的にデプロイするための Bicep テンプレートが含まれています。

## アーキテクチャ

このテンプレートは、以下の本番構成をデプロイします：

```
[Internet] → [Azure Front Door (WAF)] → [API Management] → [Azure Functions] → [Azure SQL Database]
```

### 主要コンポーネント

- **Azure Front Door Premium**: グローバルルーティング、WAF による保護
- **API Management**: 認証、レート制御、API ゲートウェイ（Developer/Premium SKU 切替可）
- **Azure Functions**: アプリケーション本体（Node.js 18）
- **Azure SQL Database**: 業務データストア
- **Application Insights**: 監視とログ
- **Storage Account**: Functions のストレージ

## ファイル

- **main.bicep**: Azure リソース全体を定義（Front Door, APIM, Functions, SQL など）
- **main.parameters.json.template**: デプロイ時に使用するパラメータファイルのテンプレート

## 前提条件

- Azure CLI がインストールされていること
- Azure サブスクリプションへのアクセス権があること
- Bicep CLI がインストールされていること（Azure CLI 2.20.0 以降に含まれています）

## デプロイ手順

### 1. パラメータファイルの作成と編集

`main.parameters.json.template` をコピーして `main.parameters.json` を作成し、以下の値を編集します：

```bash
cp main.parameters.json.template main.parameters.json
```

`main.parameters.json` を開き、以下の値を編集：

```json
{
  "sqlAdminPassword": {
    "value": "YOUR_PASSWORD_HERE"  // 強力なパスワードに変更
  },
  "allowedIps": {
    "value": ["YOUR_IP_ADDRESS_HERE"]  // 自分の IP アドレス（配列形式）
  },
  "apimSkuName": {
    "value": "Developer"  // 開発用: Developer、本番用: Premium
  },
  "apimPublisherEmail": {
    "value": "admin@example.com"  // APIM 管理者メール
  },
  "apimPublisherName": {
    "value": "Contoso"  // 組織名
  },
  "enablePrivateEndpoints": {
    "value": false  // Private Endpoint を使う場合は true（将来対応）
  }
}
```

自分の IP アドレスを確認するには：

```bash
curl ifconfig.me
```

### 重要な設定項目

- **env**: 環境識別子（dev, stg, prod など）
- **nameSuffix**: リソース名のプレフィックス（ユニークな値を推奨）
- **apimSkuName**: Developer（開発用、安価）または Premium（本番用、VNet 統合可）
- **allowedIps**: SQL Server のファイアウォールで許可する IP アドレスリスト（配列）
- **enablePrivateEndpoints**: 将来の Private Link 統合用（現在は false 推奨）

### 2. Azure にログイン

```bash
az login
```

### 3. リソースグループの作成

```bash
az group create --name rg-hands-on --location eastus2
```

### 4. Bicep テンプレートのデプロイ

```bash
az deployment group create \
  --resource-group rg-hands-on \
  --template-file main.bicep \
  --parameters main.parameters.json
```

または、パラメータをコマンドラインで指定：

```bash
az deployment group create \
  --resource-group rg-hands-on \
  --template-file main.bicep \
  --parameters \
    location=japaneast \
    env=dev \
    nameSuffix=handson \
    sqlAdminUsername=sqladmin \
    sqlAdminPassword='YourStrongPassword123!' \
    allowedIps='["203.0.113.1"]' \
    apimSkuName=Developer \
    apimPublisherEmail='admin@example.com' \
    apimPublisherName='Contoso'
```

**注意**: このデプロイには 30〜60 分かかります（API Management と Front Door のプロビジョニングに時間がかかります）。

### 5. デプロイの確認

デプロイが完了すると、出力に各リソースの情報が表示されます：

```bash
az deployment group show \
  --resource-group rg-hands-on \
  --name main \
  --query properties.outputs
```

## デプロイ後の作業

1. **SQL スクリプトの実行**
   - Azure Portal で SQL Database を開く
   - Query Editor を使用して `sql/HandsOnSetup.sql` を実行
   - サンプルデータとストアドプロシージャを作成

2. **Function App へのコードデプロイ**

   ```bash
   # リポジトリのルートディレクトリで実行
   func azure functionapp publish <functionAppName>
   ```

3. **動作確認**

   デプロイされた各エンドポイントを確認：

   ```bash
   # Functions に直接アクセス
   curl https://<functionAppName>.azurewebsites.net/api/customer/123

   # APIM 経由でアクセス（Subscription Key が必要）
   curl -H "Ocp-Apim-Subscription-Key: YOUR_KEY" \
     https://<apimName>.azure-api.net/api/customer/123

   # Front Door 経由でアクセス（推奨）
   curl https://<frontDoorEndpoint>/api/customer/123
   ```

4. **APIM Subscription Key の取得**

   ```bash
   # Azure Portal で API Management → Subscriptions から取得
   # または CLI で取得
   az apim subscription list \
     --resource-group rg-hands-on \
     --service-name <apimName> \
     --query "[0].primaryKey" -o tsv
   ```

## クリーンアップ

リソースが不要になったら、リソースグループごと削除します：

```bash
az group delete --name rg-hands-on --yes --no-wait
```

## トラブルシューティング

### デプロイエラー

- **APIM 名が既に使用されている**: `nameSuffix` パラメータを変更して別の名前を使用
- **パスワードポリシーエラー**: SQL パスワードは、大文字、小文字、数字、特殊文字を含む 8 文字以上である必要があります
- **IP アドレス形式エラー**: `allowedIps` は IPv4 形式の配列（例: ["203.0.113.1", "198.51.100.1"]）で指定してください
- **APIM デプロイが遅い**: Developer SKU でも 30〜40 分かかります。気長に待ちましょう
- **Front Door デプロイが失敗**: Premium SKU が必要です（テンプレートで設定済み）

### SQL 接続エラー

- ファイアウォールルールで IP アドレスが許可されているか確認
- Azure Portal で SQL Server → Networking → Firewall rules を確認

### APIM が Functions を呼び出せない

- APIM のバックエンド設定で Functions の URL が正しいか確認
- Functions のアクセス制限（IP 制限など）が APIM をブロックしていないか確認

### Bicep のインストール確認

```bash
az bicep version
```

バージョンが表示されない場合：

```bash
az bicep install
```

## GitHub Copilot を使った Bicep 作成

VS Code で GitHub Copilot を有効にし、以下のようなコメントから Bicep コードを生成できます：

```bicep
// Azure Front Door, API Management, Functions, SQL Database を作成する Bicep テンプレート
// - Front Door Premium with WAF
// - API Management Developer/Premium
// - 消費プランの Function App
// - Basic 層の SQL Database
// - Application Insights による監視
```

Copilot が適切なリソース定義を提案してくれます。

## 構成のカスタマイズ

### 本番環境へのスケールアップ

開発環境から本番環境に移行する際は、パラメータファイルで以下を変更：

```json
{
  "env": { "value": "prod" },
  "apimSkuName": { "value": "Premium" },  // Developer → Premium
  "enablePrivateEndpoints": { "value": true }  // 将来対応
}
```

### SKU の選択

- **APIM Developer**: 開発・テスト用、SLA なし、低コスト
- **APIM Premium**: 本番用、VNet 統合可、マルチリージョン、SLA あり

### セキュリティ強化

本番環境では以下を検討：

1. **SQL Database の Public Access を無効化**: Private Endpoint を使用
2. **APIM の Virtual Network 統合**: Internal モード
3. **Functions のアクセス制限**: APIM からのみ許可
4. **WAF ポリシーのカスタマイズ**: カスタムルール追加

## コスト見積もり

各リソースの概算月額コスト（Japan East）：

- Azure Front Door Premium: ~$330/月
- API Management Developer: ~$60/月（Premium: ~$3000/月）
- Azure Functions（消費プラン）: 使用量に応じて（無料枠あり）
- SQL Database Basic: ~$600円/月
- Storage Account: ~数百円/月
- Application Insights: 使用量に応じて（無料枠あり）

**合計**: 開発環境で約 $400/月、本番環境（Premium APIM）で約 $3700/月

---

## 次のステップ

✅ **パス3完了！** 本番レベルの Azure PaaS アーキテクチャを構築できました。

### さらに学びたい方は...

- **[💡 ハンズオンTips](ハンズオンTips.md)**: 実務で役立つ設計論点とベストプラクティス
- **[📝 API の使い方](sample-usage.md)**: デプロイした API のテスト方法
- **[README.md の Section 4](README.md#4-将来の本番構成への拡張理論編)**: 冗長化・閉域化の詳細

---

## 参考リンク

- [Bicep ドキュメント](https://docs.microsoft.com/ja-jp/azure/azure-resource-manager/bicep/)
- [Azure Front Door の Bicep リファレンス](https://docs.microsoft.com/ja-jp/azure/templates/microsoft.cdn/profiles?tabs=bicep)
- [API Management の Bicep リファレンス](https://docs.microsoft.com/ja-jp/azure/templates/microsoft.apimanagement/service?tabs=bicep)
- [Azure Functions の Bicep リファレンス](https://docs.microsoft.com/ja-jp/azure/templates/microsoft.web/sites?tabs=bicep)
- [Azure SQL Database の Bicep リファレンス](https://docs.microsoft.com/ja-jp/azure/templates/microsoft.sql/servers?tabs=bicep)
