# クイックスタートガイド

このガイドでは、最短でハンズオンを始めるための手順を説明します。

## 前提条件

- Azure サブスクリプション
- Node.js (v18 以上)
- Azure Functions Core Tools
- Visual Studio Code（推奨）
- Git

## 5分で始める

### 1. リポジトリのクローン

```bash
git clone https://github.com/ishidahra01/azure-sql-db-node-rest-api-handson.git
cd azure-sql-db-node-rest-api-handson
```

### 2. 依存パッケージのインストール

```bash
npm install
```

### 3. Azure SQL Database のセットアップ

Azure Portal で以下を実行：

1. **Resource Group の作成**
   - 名前: `rg-hands-on`
   - リージョン: `Japan East`

2. **Azure SQL Database の作成**
   - サーバー名: 任意（例: `handson-sql-server-xxx`）
   - データベース名: `hands_on_db`
   - 価格レベル: `Basic`（最小コスト）
   - 管理者ユーザー名とパスワードを設定

3. **ファイアウォールの設定**
   - SQL Server の「Networking」→「Firewall rules」
   - 「Add client IP」をクリックして自分の IP を追加

4. **SQL スクリプトの実行**
   - データベースの「Query editor」を開く
   - 管理者資格情報でログイン
   - `sql/HandsOnSetup.sql` の内容を貼り付けて実行

### 4. ローカル設定ファイルの作成

```bash
cp local.settings.json.template local.settings.json
```

`local.settings.json` を編集して接続情報を入力：

```json
{
  "IsEncrypted": false,
  "Values": {
    "FUNCTIONS_WORKER_RUNTIME": "node",
    "AzureWebJobsStorage": "UseDevelopmentStorage=true",
    "db_server": "handson-sql-server-xxx.database.windows.net",
    "db_database": "hands_on_db",
    "db_user": "your_admin_user",
    "db_password": "your_password"
  }
}
```

### 5. Azurite の起動

**VS Code の場合:**
- コマンドパレット（Ctrl+Shift+P / Cmd+Shift+P）
- "Azurite: Start" を選択

**ターミナルの場合:**
```bash
npm install -g azurite
azurite --silent --location /tmp/azurite --debug /tmp/azurite/debug.log &
```

### 6. Azure Functions の起動

```bash
func start
```

または VS Code で F5 キーを押してデバッグ実行。

### 7. API のテスト

```bash
curl http://localhost:7071/api/customer/123
```

期待される結果:

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

✅ **成功！** Functions から Azure SQL にアクセスできました。

## 次のステップ

- すべての顧客を取得: `curl http://localhost:7071/api/customer`
- [Azure へのデプロイ](README.md#step-3-azure-へのデプロイオプション)
- [Bicep での IaC 体験](BICEP_README.md)
- [詳細なドキュメント](README.md)

## トラブルシューティング

### エラー: "Error connecting to Azure SQL query"

**原因:** ファイアウォールで IP が許可されていない

**解決策:**
1. Azure Portal で SQL Server を開く
2. 「Networking」→「Firewall rules」
3. 自分の IP アドレスを確認: `curl ifconfig.me`
4. その IP アドレスを許可するルールを追加

### エラー: "AzureWebJobsStorage connection string is invalid"

**原因:** Azurite が起動していない

**解決策:**
- VS Code: コマンドパレットから "Azurite: Start"
- ターミナル: `azurite --silent --location /tmp/azurite --debug /tmp/azurite/debug.log &`

### エラー: "Could not find stored procedure 'dbo.GetCustomerById'"

**原因:** SQL スクリプトが実行されていない

**解決策:**
- Azure Portal の Query Editor で `sql/HandsOnSetup.sql` を実行

### Node.js のバージョンが古い

```bash
node --version
```

v18 以上が必要です。更新方法:
- [Node.js 公式サイト](https://nodejs.org/)からダウンロード
- または nvm を使用: `nvm install 18`

### Azure Functions Core Tools がインストールされていない

```bash
npm install -g azure-functions-core-tools@4 --unsafe-perm true
```

## ヘルプ

問題が解決しない場合は、GitHub Issues で質問してください。

## 参考リンク

- [Azure Functions のローカル開発](https://learn.microsoft.com/ja-jp/azure/azure-functions/functions-develop-local)
- [Azure SQL Database のクイックスタート](https://learn.microsoft.com/ja-jp/azure/azure-sql/database/single-database-create-quickstart)
- [Visual Studio Code で Azure Functions を開発する](https://learn.microsoft.com/ja-jp/azure/azure-functions/functions-develop-vs-code)
