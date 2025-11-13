# 📝 サンプル REST API の使い方

> **このドキュメントの対象者**: 全員（API のテスト方法を知りたい方）  
> **使用タイミング**: Functions が起動した後、API をテストする時  
> **目的**: API の全エンドポイントと使用例、トラブルシューティングを参照

このハンズオンでは、シンプルな GET リクエストのみをサポートしています。

## ローカルで Azure Functions を起動

```bash
func start
```

または Visual Studio Code の Azure Functions Extension から F5 でデバッグ実行します。

詳細は [Azure Functions をローカルでコーディングしてテストする](https://docs.microsoft.com/ja-jp/azure/azure-functions/functions-develop-local) を参照してください。

## 特定の顧客を取得

```bash
curl http://localhost:7071/api/customer/123
```

レスポンス例:

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

## すべての顧客を取得

```bash
curl http://localhost:7071/api/customer
```

レスポンス例:

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
    },
    {
        "CustomerID": 124,
        "CustomerName": "Wingtip Toys (Seattle, WA)",
        "PhoneNumber": "(206) 555-0200",
        "WebsiteURL": "http://www.wingtiptoys.com",
        "AddressLine1": "456 Main Street",
        "AddressLine2": "Suite 100",
        "PostalCode": "98101"
    }
]
```

## Azure にデプロイした後のテスト

デプロイが完了したら、Function App の URL を使ってテストします:

```bash
curl https://<your-function-app-name>.azurewebsites.net/api/customer/123
```

## トラブルシューティング

### エラー: "Error connecting to Azure SQL query"

- Azure SQL Server のファイアウォール設定を確認してください
- ローカルテスト時は、開発端末のIPアドレスを許可する必要があります
- Azure にデプロイした場合は、Function App の送信IPアドレスを許可する必要があります

### エラー: "AzureWebJobsStorage connection string is invalid"

- Azurite が起動しているか確認してください
- VS Code の場合: コマンドパレットから "Azurite: Start" を実行
- ターミナルの場合: `azurite --silent --location /tmp/azurite --debug /tmp/azurite/debug.log`

### エラー: "Could not find stored procedure"

- `sql/HandsOnSetup.sql` を Azure SQL Database で実行したか確認してください
- Azure Portal の Query Editor または Azure Data Studio から実行できます

