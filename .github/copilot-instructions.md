# Azure PaaS ハンズオン - GitHub Copilot カスタム指示

このリポジトリは、Azure Functions と Azure SQL Database を使った REST API のハンズオン教材です。Infrastructure as Code (IaC) として Bicep を使用し、段階的に Azure PaaS アーキテクチャを学習します。

## プロジェクト概要

**目的**: Azure Functions と Azure SQL Database を使って最小限の REST API を実装し、将来的に Front Door → APIM → Functions → SQL という本番構成への拡張を理解する

**対象者**: Azure PaaS の基本を学ぶ開発者、IaC を体験したい方

**主要技術スタック**:
- **Runtime**: Node.js 18 (Azure Functions v4)
- **Database**: Azure SQL Database
- **IaC**: Azure Bicep
- **Dependencies**: tedious (SQL Server driver for Node.js)
- **Deployment**: Azure CLI, func コマンド

## リポジトリ構造

```
azure-sql-db-node-rest-api-handson/
├── .github/                      # GitHub 設定
├── customer/                     # Azure Functions HTTP トリガー
│   ├── index.js                 # メインロジック (GET /customer/{id})
│   └── function.json            # Function 設定
├── sql/                          # Azure SQL Database スクリプト
│   ├── HandsOnSetup.sql         # 初期セットアップ SQL
│   └── WideWorldImportersUpdates.sql
├── main.bicep                    # IaC メインテンプレート
├── main.parameters.json.template # Bicep パラメータテンプレート
├── azure-deploy.sh              # デプロイスクリプト
├── local.settings.json.template # Functions ローカル設定テンプレート
├── host.json                     # Functions ホスト設定
├── package.json                  # Node.js 依存関係
├── README.md                     # メインドキュメント
├── BICEP_README.md              # Bicep デプロイガイド
├── QUICKSTART.md                # クイックスタート
└── sample-usage.md              # API 使用例
```

## ビルドと実行手順

### 前提条件

1. **必須ツール**:
   - Node.js 18 以上
   - Azure Functions Core Tools v4
   - Azure CLI
   - Bicep CLI (Azure CLI 2.20.0+ に含まれる)

2. **Azure リソース**:
   - Azure サブスクリプション
   - Azure SQL Database (事前作成が必要)
   - SQL Server ファイアウォールルールで開発端末 IP を許可

### ローカル開発環境のセットアップ

**重要**: 以下の手順は順番通りに実行してください。

1. **依存パッケージのインストール**:
   ```bash
   npm install
   ```
   - `tedious` パッケージ (SQL Server クライアント) がインストールされます
   - このステップは**必須**で、Functions 起動前に完了している必要があります

2. **ローカル設定ファイルの作成**:
   ```bash
   cp local.settings.json.template local.settings.json
   ```
   - `local.settings.json` を編集し、以下を設定:
     - `db_server`: Azure SQL Server FQDN (例: `yourserver.database.windows.net`)
     - `db_database`: データベース名
     - `db_user`: SQL ユーザー名
     - `db_password`: SQL パスワード

3. **Azurite の起動** (ローカルストレージエミュレータ):
   - VS Code 拡張機能から: コマンドパレット → "Azurite: Start"
   - またはターミナル: `azurite --silent --location /tmp/azurite`
   - **必須**: Functions のローカル実行には Azurite が起動している必要があります

4. **Azure Functions の起動**:
   ```bash
   npm start
   # または
   func start
   ```
   - 起動後、`http://localhost:7071` でリッスンします
   - エンドポイント: `GET http://localhost:7071/api/customer/{id}`

5. **API のテスト**:
   ```bash
   curl http://localhost:7071/api/customer/123
   ```

### Azure へのデプロイ

**方法 1: デプロイスクリプトを使用**:
```bash
bash azure-deploy.sh
```
- ユニークな識別子の入力を求められます (例: `tanaka`)
- リソースグループ、Storage Account、Function App、Application Insights が自動作成されます
- **ローカルコード**が Azure にデプロイされます (GitHub からではない)

**方法 2: Bicep テンプレートを使用** (推奨):
```bash
# 1. パラメータファイルを作成
cp main.parameters.json.template main.parameters.json
# パラメータファイルを編集して SQL パスワードと IP アドレスを設定

# 2. リソースグループを作成
az group create --name rg-hands-on --location japaneast

# 3. Bicep テンプレートをデプロイ
az deployment group create \
  --resource-group rg-hands-on \
  --template-file main.bicep \
  --parameters main.parameters.json

# 4. Functions コードをデプロイ
func azure functionapp publish <functionAppName>
```

### SQL データベースのセットアップ

**Azure SQL Database にサンプルデータを投入**:

1. Azure Portal で SQL Database を開く
2. Query Editor を使用して `sql/HandsOnSetup.sql` を実行
3. 以下が作成されます:
   - `dbo.Customers` テーブル
   - `dbo.GetCustomerById` ストアドプロシージャ
   - `dbo.GetAllCustomers` ストアドプロシージャ
   - サンプルデータ (CustomerID: 123)

## アーキテクチャ設計原則

### 現在の最小構成 (フェーズ1)
```
[開発端末/curl] → [Azure Functions (HTTP)] → [Azure SQL Database]
```

### 将来の本番構成 (フェーズ2)
```
[Internet] → [Azure Front Door (WAF)] → [APIM (認証/レート制御)] → [Functions] → [SQL]
```

### 主要コンポーネント

1. **Azure Functions (customer/index.js)**:
   - HTTP トリガー (GET メソッドのみサポート)
   - tedious パッケージで Azure SQL に接続
   - ストアドプロシージャを呼び出して JSON を返す
   - エラーハンドリング: SQL 接続エラー、無効な ID

2. **Azure SQL Database**:
   - デフォルトでパブリックアクセスは拒否
   - ファイアウォールルールで許可した IP のみ接続可能
   - ストアドプロシージャで `FOR JSON PATH` を使用

3. **Infrastructure as Code (Bicep)**:
   - リソースを宣言的に定義
   - パラメータは `main.bicep` で集約
   - Application Insights による監視を含む

## コーディングガイドライン

### Functions コードの変更時

- **接続管理**: `tedious` の Connection オブジェクトは使用後に適切にクローズされます
- **環境変数**: `process.env` から DB 接続情報を取得 (ハードコード禁止)
- **エラーハンドリング**: すべての SQL 操作でエラーをキャッチし、適切な HTTP ステータスコードを返す
- **メソッド制限**: このハンズオンは GET メソッドのみをサポート (405 を返す)

### SQL スクリプトの変更時

- **ストアドプロシージャ**: 必ず `FOR JSON PATH` を使用して JSON を返す
- **パラメータ化**: SQL インジェクションを防ぐため、パラメータ化されたクエリを使用
- **トランザクション**: 複数の操作を行う場合は適切にトランザクションを管理

### Bicep テンプレートの変更時

**厳守すべきルール**:

1. **ネーミング規則**:
   - リソースグループ: `rg-<app>-<env>`
   - Azure Front Door: `afdr-<app>-<env>`
   - API Management: `apim-<app>-<env>`
   - Function App: `func-<app>-<env>`
   - Storage Account: `st<app><env>` (小文字、24文字以内)
   - SQL Server: `sql-<app>-<env>`
   - SQL Database: `sqldb-<app>-<env>`

2. **パラメータ管理**:
   - **すべてのパラメータは `main.bicep` で集約**
   - location, env, nameSuffix, SKU などを一元管理
   - モジュール分割時もパラメータは親テンプレートから渡す

3. **IaC のスコープ**:
   - **リソース定義のみ**を行う
   - アプリケーションコードのデプロイは IaC の対象外
   - Function App の作成まで、コードデプロイは別手順

4. **セキュリティ**:
   - SQL パスワードは `@secure()` デコレータを使用
   - パブリックアクセスが必要なリソースは明示的に設定
   - TLS 1.2 以上を強制

### 依存関係の追加

新しい npm パッケージを追加する場合:
```bash
npm install <package-name>
```
- `package.json` が自動更新されます
- ローカルとデプロイ先の両方で同じバージョンを使用

---

## Copilot への指示

このファイルの指示を信頼し、必要な情報が不足している場合や誤りがある場合のみ、追加の検索を行ってください。

コード生成時は、このプロジェクトの既存のパターンとベストプラクティスに従ってください。特に、Bicep ファイルの編集時は、上記のネーミング規則とパラメータ管理のルールを厳守してください。
