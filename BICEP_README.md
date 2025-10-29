# Bicep を使った IaC デプロイ

このディレクトリには、Azure リソースを宣言的にデプロイするための Bicep テンプレートが含まれています。

## ファイル

- **main.bicep**: Azure Functions、Azure SQL Database、Storage Account、Application Insights などのリソースを定義
- **main.parameters.json**: デプロイ時に使用するパラメータファイル

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
  "clientIpAddress": {
    "value": "YOUR_IP_ADDRESS_HERE"  // 自分の IP アドレスに変更
  }
}
```

自分の IP アドレスを確認するには：

```bash
curl ifconfig.me
```

### 2. Azure にログイン

```bash
az login
```

### 3. リソースグループの作成

```bash
az group create --name rg-hands-on --location japaneast
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
    projectName=handson \
    sqlAdminUsername=sqladmin \
    sqlAdminPassword='YourStrongPassword123!' \
    clientIpAddress='YOUR_IP_ADDRESS'
```

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
   ```bash
   curl https://<functionAppName>.azurewebsites.net/api/customer/123
   ```

## クリーンアップ

リソースが不要になったら、リソースグループごと削除します：

```bash
az group delete --name rg-hands-on --yes --no-wait
```

## トラブルシューティング

### デプロイエラー

- **SQL Server 名が既に使用されている**: `projectName` パラメータを変更して別の名前を使用
- **パスワードポリシーエラー**: SQL パスワードは、大文字、小文字、数字、特殊文字を含む 8 文字以上である必要があります
- **IP アドレス形式エラー**: `clientIpAddress` は IPv4 形式（例: 203.0.113.1）で指定してください

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
// Azure Functions と Azure SQL Database を作成する Bicep テンプレート
// - 消費プランの Function App
// - Basic 層の SQL Database
// - Application Insights による監視
```

Copilot が適切なリソース定義を提案してくれます。

## 参考リンク

- [Bicep ドキュメント](https://docs.microsoft.com/ja-jp/azure/azure-resource-manager/bicep/)
- [Azure Functions の Bicep リファレンス](https://docs.microsoft.com/ja-jp/azure/templates/microsoft.web/sites?tabs=bicep)
- [Azure SQL Database の Bicep リファレンス](https://docs.microsoft.com/ja-jp/azure/templates/microsoft.sql/servers?tabs=bicep)
