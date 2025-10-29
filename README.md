# Azure PaaS ハンズオンガイド

Functions + Azure SQL REST API / APIM / Front Door までの設計イメージ

---

## 0. このハンズオンの目的

このハンズオンは、今後お客様が Azure 上でアプリケーションを設計・実装していくための「最初の一歩」を明確にすることを目的としています。

* **Azure Functions と Azure SQL Database を使って最小限の REST API を実装・動作させる**

  * まずは `Functions → Azure SQL` を自分の手で動かすことで、Azure PaaS の基本的な開発・接続モデルを理解する

* **GitHub Copilot などのコーディングエージェントを使い、インフラ構築 (IaC) の下書きを自動生成する体験をする**

  * Azure リソースを手作業でポータルから作るのではなく、スクリプト/Terraform/Bicep など「宣言的につくる」流れに慣れる

* **将来的な本番構成（Front Door → APIM → Functions → Azure SQL）の考え方をイメージし、冗長化や閉域構成の論点を把握する**

  * 冗長化をどこまでやるか
  * 閉域化 (Private Link / VNet 統合など) をどこまでやるか
  * コストと可用性のトレードオフをどこで判断するか
    これらは Azure の SKU/ネットワーク設計に強く依存するため、最初に前提を共有しておくことが重要です。([Microsoft Learn][1])

> 前提
> Azure の PaaS には「どこまでマネージドか」「どこからネットワークを閉じられるか」「SKUで機能が変わるか」といった設計上の考え方の違いがあります。これを早期に理解していただくことで、設計・開発・検証のスピードを上げる狙いがあります。([Microsoft Learn][2])

---

## 1. ゴールイメージ（到達点）

### ゴールA（必須）

* 各参加者が **自分の Azure サブスクリプション上に Azure SQL Database を作成**し、サンプルのテーブル/データを投入する
* ローカルの Azure Functions (Node.js) から、その Azure SQL Database に接続し、REST API (`GET /customer/{id}`) でレコードを取得できること

> ここまでで「Functions から SQL を叩けた」「JSON が返ってきた」という成功体験を得るのが最優先ゴールです。

Azure SQL Database は作成直後は外部からの接続が拒否されており、アクセスを許可したいクライアント IP をファイアウォール ルールとして登録する必要があります。これは Azure ポータルや CLI から設定でき、"このクライアント IP を許可" といった操作で自分の開発端末のグローバル IP を許可できます。([Microsoft Learn][3])

### ゴールB（できれば到達）

* Functions アプリと Azure SQL Database を Azure 上にデプロイし、クラウド側のエンドポイントでも同じ API が動作すること
* GitHub Copilot の支援を受けながら、Bicep/Terraform/az cli などでリソースを宣言的に定義する雛形 (IaC) を用意すること

  * Resource Group、Function App、SQL Server/DB、アプリ設定 など

### ゴールC（アーキテクチャの理解）

* 将来的な本番候補アーキテクチャ
  `Front Door → API Management (APIM) → Functions → Azure SQL`
* 可用性・冗長化（リージョン冗長 / ゾーン冗長）、閉域化（Private Link / VNet 統合）、WAF/レート制御/監査ログなどの論点を言語化できる状態になること。
  Azure Front Door はグローバルなエントリポイント兼グローバル負荷分散・WAF/ルーティング機能を提供し、API Management は認証・レート制御・変換・開発者ポータルなど API 全体の管理を行うコンポーネントとして設計されています。([Microsoft Learn][4])

---

## 2. アーキテクチャのロードマップ

### フェーズ1（本ハンズオンで実際に動かす最小構成）

```text
[Developer PC / curl] 
      ↓ HTTP
[Azure Functions (HTTP Trigger, Node.js)]
      ↓ SQL Query
[Azure SQL Database (各自が作成)]
```

* Functions はローカル実行（Azure Functions Core Tools で起動）
* DB は各自の Azure SQL Database（クラウド上）
* これにより「アプリ本体はローカルでも、データはクラウドにある」状態で疎通を確認します
  このとき Functions の `local.settings.json` の接続情報に、自分の Azure SQL Database のサーバー名 (例: `<name>.database.windows.net`)・DB名・ユーザー名・パスワードを入れます。([Microsoft Learn][3])

ローカル実行時、Functions はストレージとしてローカルの Azurite エミュレータを使えます。`"AzureWebJobsStorage": "UseDevelopmentStorage=true"` と設定すると、実際のクラウド Storage アカウントなしでローカルテストできます。([Microsoft Learn][5])

### フェーズ2（将来の本番構成イメージ）

```text
[Internet Client / Browser / Mobile App]
           ↓
[Azure Front Door (WAF / Global routing)]
           ↓
[Azure API Management (認証, レート制御, 変換, ログ)]
           ↓
[Azure Functions (アプリ本体)]
           ↓
[Azure SQL Database (業務データ)]
```

* **Azure Front Door**
  グローバルなエントリポイントとして、WAF（Web Application Firewall）、TLS終端、パスベースルーティング、ヘルスプローブによるフェイルオーバー、グローバル負荷分散、CDN 的な配信最適化を提供します。([Microsoft Learn][4])

* **Azure API Management (APIM)**
  API Gateway / 管理プレーン / Developer Portal で構成されます。API の発行管理、サブスクリプションキーや OAuth2 等の認証、レートリミットやクォータによるスロットリング、リクエスト/レスポンス変換、監視・ログなどを一元的に定義できます。これによりバックエンド Functions のコードをシンプルに保ちつつ、外部公開ポリシーを集中管理できます。([Microsoft Learn][6])

* **Azure Functions**
  サーバーレスの実行基盤としてイベント駆動でスケールします。消費プラン（従量課金・スケールアウト）から Premium プラン（コールドスタート抑制・VNet統合など拡張機能）など、ホスティングプランにより機能/ネットワーク統合レベルを選べます。([Microsoft Learn][1])

* **Azure SQL Database**
  マネージドな PaaS SQL Server。バックアップ・パッチ適用・高可用性がサービス側で提供され、アプリ側は通常の接続文字列でクエリできます。アクセスはデフォルト拒否で、明示的に許可した IP / Private Link 等のみ接続可能とする設計が基本です。([Microsoft Learn][3])

---

## 3. ハンズオンの進め方（ステップ別）

### Step 0. 事前準備（各参加者が実施すること）

このステップでは、各参加者自身が Azure 上に最小限のインフラ（Resource Group、Azure SQL Database）を作り、サンプルデータを投入します。講師側で共通の DB を配布する方式ではなく、**各自の環境を自分で用意**してもらいます。

1. **Azure リソースグループを作成**

   * 例: `rg-hands-on`（リージョンは japaneast など任意）
   * `az group create -n rg-hands-on -l japaneast` のような形で作成可能（後述の付録Aに例あり）

2. **Azure SQL Database（シングルDB）を作成**

   * Azure ポータルから「Azure SQL」→「SQL データベース」を作成
   * 最小コスト帯（Basic / サーバーレスなど）でかまいません
   * いわゆる「論理サーバー」も同時に作成します（`<yourserver>.database.windows.net` の形になる FQDN は後で Functions から接続するので必ず控えておく）
   * 作成後、サーバーレベルのファイアウォール設定で「自分のクライアント IP を許可」してください

     * これは Azure SQL Database がデフォルトで全ての外部接続を拒否しており、明示的に許可した IP のみ接続を通すためです
     * ポータルの「Networking / Firewall rules」画面から、"Add client IP" で現在の開発端末のグローバルIPを許可できます
     * 必要に応じて、このルールは後で削除／絞り込みしてください（本番ではより厳しく管理します）
       Azure SQL Database では、サーバーレベル/データベースレベルのファイアウォールルールを介して特定IPやIPレンジだけを許可する形でアクセス制御します。([Microsoft Learn][3])

3. **サンプルスキーマを作成してデータを投入**
   以下は最小動作確認用のサンプル（本番用ではありません）。
   Azure ポータルの DB 画面 > "Query editor (preview)" から直接クエリを実行できます。Azure Data Studio や SSMS から接続してクエリしても構いません。これらのツールは Azure SQL Database に接続し、T-SQL を発行してテーブル作成やデータ挿入ができます。([Microsoft Learn][7])

   例として、`Customers` テーブルと、ID 指定で 1 件返すストアドプロシージャを作ります。

   ```sql
   CREATE TABLE dbo.Customers (
       CustomerID     INT PRIMARY KEY,
       CustomerName   NVARCHAR(200),
       PhoneNumber    NVARCHAR(50),
       WebsiteURL     NVARCHAR(200),
       AddressLine1   NVARCHAR(200),
       AddressLine2   NVARCHAR(200),
       PostalCode     NVARCHAR(20)
   );

   INSERT INTO dbo.Customers
       (CustomerID, CustomerName, PhoneNumber, WebsiteURL,
        AddressLine1, AddressLine2, PostalCode)
   VALUES
       (123,
        N'Tailspin Toys (Roe Park, NY)',
        N'(212) 555-0100',
        N'http://www.tailspintoys.com/RoePark',
        N'Shop 219',
        N'528 Persson Road',
        N'90775');

   GO

   CREATE OR ALTER PROCEDURE dbo.GetCustomerById
       @CustomerID INT
   AS
   BEGIN
       SET NOCOUNT ON;
       SELECT
           c.CustomerID,
           c.CustomerName,
           c.PhoneNumber,
           c.WebsiteURL,
           c.AddressLine1,
           c.AddressLine2,
           c.PostalCode
       FROM dbo.Customers AS c
       WHERE c.CustomerID = @CustomerID
       FOR JSON PATH;
   END
   GO
   ```

   > 後続の Functions コードは、このストアドプロシージャやテーブルを叩いて JSON を返すイメージになります。
   > このリポジトリの `sql/` ディレクトリにスクリプトが用意されているので、そちらも参照してください。

4. **接続情報を控える**

   * サーバー名（例: `yourserver.database.windows.net`）
   * データベース名（例: `hands_on_db`）
   * ログインユーザー / パスワード
     Functions のローカル実行時および後続のデプロイで使用します。([Microsoft Learn][3])

5. **ローカル開発環境の準備**

   * Node.js (LTS推奨、v18 以上)
   * Azure Functions Core Tools
   * Visual Studio Code

     * Azure Functions Extension
     * GitHub Copilot Extension（推奨）
   * Azurite（VS Code 拡張 or npmから起動）
     Azure Functions のローカル実行時は、`"AzureWebJobsStorage": "UseDevelopmentStorage=true"` を設定すると Azurite がローカルのストレージエミュレーションとして扱われます。これは、キュー／ブロブ／テーブルなど Functions のトリガー・バインディングが依存する Storage をクラウドに作らずにテストできるようにするものです。([Microsoft Learn][5])

---

### Step 1. リポジトリの理解

このリポジトリの構成を確認します。

* **`customer/`**
  * Azure Functions の HTTP トリガー Function
  * `GET /customer/{id}` のようなルートで呼び出され、SQL を実行して JSON を返す
  * `index.js` に Functions のコードロジック
  * `function.json` に HTTP トリガーの設定

* **`sql/`**
  * サンプルDBに必要な T-SQL（ストアドプロシージャなど）
  * `HandsOnSetup.sql`: このハンズオン用の最小スキーマとサンプルデータ

* **`local.settings.json.template`**
  * ローカル実行時の設定テンプレート
  * DB接続情報や `AzureWebJobsStorage` の値をここで指定

* **`azure-deploy.sh`**
  * Azure CLI を使ってリソースグループ作成～Function Appデプロイまで行うスクリプト

* **`host.json`** / **`package.json`**
  * Node.js の依存関係と Function のエントリポイント

Azure Functions 側では、HTTP リクエストを受け取り、パラメータ（idなど）を読み取り、Azure SQL にクエリを投げて結果を JSON として返します。
これは「サーバーレスな関数（Functions）が REST API のエンドポイントとして動く」パターンで、AWS Lambda + API Gateway でよくある構成と類似します。([Microsoft Learn][8])

---

### Step 2. ローカル実行（Functions → 各自の Azure SQL）

1. **リポジトリをクローン**

   ```bash
   git clone https://github.com/ishidahra01/azure-sql-db-node-rest-api-handson.git
   cd azure-sql-db-node-rest-api-handson
   ```

2. **依存パッケージのインストール**

   ```bash
   npm install
   ```

3. **`local.settings.json` の作成**
   リポジトリにある `local.settings.json.template` をコピーして `local.settings.json` を作成し、以下のように編集します。

   ```json
   {
     "IsEncrypted": false,
     "Values": {
       "FUNCTIONS_WORKER_RUNTIME": "node",
       "AzureWebJobsStorage": "UseDevelopmentStorage=true",
       "db_server": "<yourserver>.database.windows.net",
       "db_database": "hands_on_db",
       "db_user": "your_admin_user",
       "db_password": "your_password"
     }
   }
   ```

   * `<yourserver>`: Step 0 で作成した Azure SQL Server の名前
   * `hands_on_db`: 作成したデータベース名
   * `your_admin_user` / `your_password`: データベースのログイン情報

4. **Azurite の起動**（ローカルストレージエミュレータ）

   VS Code で Azurite を拡張機能からインストールしている場合、コマンドパレットから "Azurite: Start" を実行します。
   または、別ターミナルで以下を実行：

   ```bash
   npm install -g azurite
   azurite --silent --location /tmp/azurite --debug /tmp/azurite/debug.log
   ```

5. **Azure Functions をローカルで起動**

   ```bash
   func start
   ```

   または Visual Studio Code の Azure Functions Extension から F5 でデバッグ実行します。

   起動後、以下のようなログが表示されます：

   ```text
   Now listening on: http://0.0.0.0:7071
   Application started. Press Ctrl+C to shut down.

   Http Functions:

           customer: [GET,PUT,PATCH,DELETE] http://localhost:7071/api/customer/{id:int?}
   ```

6. **API をテストする**

   別のターミナルまたはブラウザから以下を実行：

   ```bash
   curl http://localhost:7071/api/customer/123
   ```

   期待される結果（JSON）:

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

   > **成功！** これで「ローカルの Functions から Azure SQL にアクセスして JSON を返す」ことができました。

---

### Step 3. Azure へのデプロイ（オプション）

ローカルで動作確認できたら、次は Azure 上にデプロイしてクラウド環境で動作させます。

1. **Azure CLI でログイン**

   ```bash
   az login
   ```

2. **デプロイスクリプトの実行**

   このリポジトリには `azure-deploy.sh` というデプロイスクリプトが用意されています。
   スクリプトを開いて、以下の変数を自分の環境に合わせて編集します：

   ```bash
   resourceGroup="rg-hands-on"
   appName="func-hands-on-app"
   storageName="sthandsonstorage"
   location="japaneast"
   ```

   編集後、スクリプトを実行：

   ```bash
   bash azure-deploy.sh
   ```

   スクリプトは以下を自動で実行します：
   * Resource Group の作成
   * Storage Account の作成
   * Application Insights の作成
   * Function App の作成
   * Functions コードのデプロイ
   * アプリケーション設定（DB接続情報）の設定

3. **デプロイされた API をテスト**

   デプロイが完了すると、Function App の URL が表示されます。例：

   ```text
   https://func-hands-on-app.azurewebsites.net
   ```

   この URL に対して API をテスト：

   ```bash
   curl https://func-hands-on-app.azurewebsites.net/api/customer/123
   ```

   ローカルと同じ JSON レスポンスが返ってくれば成功です。

---

### Step 4. IaC（Infrastructure as Code）の体験

**GitHub Copilot を使った IaC 雛形の生成**

手動でポータルやスクリプトでリソースを作るのではなく、Infrastructure as Code (IaC) のアプローチで宣言的にインフラを定義します。

例: Bicep を使った定義

1. **Bicep ファイルを作成**

   VS Code で新しいファイル `main.bicep` を作成し、GitHub Copilot に以下のようなプロンプトを与えます：

   ```text
   // Azure Functions と Azure SQL Database をデプロイする Bicep テンプレートを作成してください
   // - Resource Group: rg-hands-on
   // - Location: japaneast
   // - Storage Account for Functions
   // - Function App (Node.js)
   // - Azure SQL Server と Database
   // - Application Insights
   ```

   Copilot が Bicep コードを生成してくれます。

2. **Bicep のデプロイ**

   ```bash
   az deployment sub create --location japaneast --template-file main.bicep
   ```

   > これにより、スクリプトでやっていたことが「コードで定義された状態」として管理できるようになります。
   > GitHub リポジトリで管理すれば、変更履歴も残り、再現性の高いインフラ構築が可能です。

**Terraform を使った例も同様です。** Copilot に Terraform のコードを生成させ、`terraform apply` でデプロイできます。

---

## 4. 将来の本番構成への拡張（理論編）

### 4.1 Azure Front Door の追加

グローバルなエントリポイントとして Azure Front Door を配置します。

* **メリット**
  * グローバル負荷分散
  * WAF による攻撃防御
  * TLS 終端とカスタムドメイン対応
  * ヘルスチェックとフェイルオーバー

* **設定のポイント**
  * オリジンとして API Management または Functions を指定
  * ルーティングルールでパスベースの振り分け
  * WAF ポリシーで SQL インジェクションや XSS などを防御

### 4.2 Azure API Management (APIM) の追加

Functions の前段に APIM を配置し、API の管理・ポリシー適用を行います。

* **メリット**
  * API のバージョン管理
  * サブスクリプションキーや OAuth2 による認証
  * レートリミット・クォータによるスロットリング
  * リクエスト/レスポンスの変換・キャッシュ
  * 開発者ポータルで API ドキュメント公開

* **設定のポイント**
  * バックエンドとして Functions を指定
  * インバウンド/アウトバウンドポリシーで認証・変換ロジックを定義
  * Front Door からの通信のみ許可する制限を設定

### 4.3 閉域化（Private Link / VNet 統合）

本番環境では、パブリックインターネットからのアクセスを制限し、閉域ネットワーク内で通信させることが重要です。

* **Azure SQL Database**
  * Private Endpoint を使用してプライベート IP でアクセス
  * パブリックエンドポイントを無効化

* **Azure Functions**
  * Premium プラン以上で VNet 統合が可能
  * プライベートサブネット内に配置

* **APIM**
  * Internal モードで VNet 内に配置
  * Private Endpoint 経由でアクセス

* **構成イメージ**
  ```text
  [Internet] → [Front Door (Public)] → [APIM (Internal VNet)] → [Functions (VNet統合)] → [SQL (Private Endpoint)]
  ```

### 4.4 冗長化・可用性

* **リージョン冗長**
  * 複数リージョンに Functions と SQL をデプロイ
  * Front Door でアクティブ/アクティブまたはアクティブ/パッシブ構成

* **ゾーン冗長**
  * Premium プランや Business Critical SKU でゾーン冗長サポート
  * Azure SQL Database は Business Critical でゾーン冗長可能

* **自動フェイルオーバー**
  * SQL Database のフェイルオーバーグループ
  * Front Door のヘルスプローブで異常検知時に別リージョンへ切り替え

### 4.5 監視・ログ

* **Application Insights**
  * Functions のパフォーマンス監視
  * エラーログ・トレースの収集

* **Azure Monitor**
  * SQL Database のクエリパフォーマンス監視
  * リソース使用率・アラート設定

* **Log Analytics**
  * 集約ログ分析
  * APIM の API 呼び出しログ

---

## 5. トラブルシューティング

### ローカル実行時によくあるエラー

**1. Azure SQL への接続エラー**

```
Error connecting to Azure SQL query
```

* **原因**: ファイアウォールルールで開発端末のIPが許可されていない
* **対処**: Azure ポータルで SQL Server のファイアウォール設定を確認し、クライアントIPを追加

**2. Azurite が起動していない**

```
AzureWebJobsStorage connection string is invalid
```

* **原因**: Azurite が起動していない、または接続文字列が間違っている
* **対処**: Azurite を起動するか、`local.settings.json` の `AzureWebJobsStorage` を確認

**3. ストアドプロシージャが見つからない**

```
Could not find stored procedure 'dbo.GetCustomerById'
```

* **原因**: SQL スクリプトが実行されていない
* **対処**: `sql/HandsOnSetup.sql` を Azure SQL Database で実行

### Azure デプロイ時によくあるエラー

**1. Function App が起動しない**

* **原因**: アプリケーション設定が正しくない、または依存パッケージがインストールされていない
* **対処**: Azure ポータルで Function App の「構成」から環境変数を確認

**2. SQL への接続タイムアウト**

* **原因**: Function App の送信 IP が SQL Server のファイアウォールで許可されていない
* **対処**: Function App の送信 IP を確認し、SQL Server のファイアウォールルールに追加

---

## 6. まとめと次のステップ

このハンズオンを通じて、以下を達成しました：

- [x] Azure SQL Database の作成とサンプルデータ投入
- [x] Azure Functions (Node.js) でのシンプルな REST API 実装
- [x] ローカル開発環境からクラウド DB への接続
- [x] Azure へのデプロイ
- [x] IaC (Bicep/Terraform) の体験
- [x] 本番構成へのロードマップの理解

### 次のステップ

* **実際のアプリケーション開発**: より複雑なビジネスロジックを Functions に実装
* **APIM の導入**: API のポリシー管理・認証を追加
* **Front Door の導入**: グローバル負荷分散と WAF を設定
* **閉域化**: VNet 統合と Private Endpoint の設定
* **CI/CD パイプライン**: GitHub Actions や Azure DevOps での自動デプロイ
* **監視とアラート**: Application Insights と Azure Monitor の活用

---

## 付録A: Azure CLI クイックリファレンス

### Resource Group の作成

```bash
az group create --name rg-hands-on --location japaneast
```

### SQL Server と Database の作成

```bash
# SQL Server の作成
az sql server create \
  --name <yourserver> \
  --resource-group rg-hands-on \
  --location japaneast \
  --admin-user <admin_user> \
  --admin-password <admin_password>

# Database の作成
az sql db create \
  --resource-group rg-hands-on \
  --server <yourserver> \
  --name hands_on_db \
  --service-objective Basic

# ファイアウォールルール追加（自分のIP）
az sql server firewall-rule create \
  --resource-group rg-hands-on \
  --server <yourserver> \
  --name AllowMyIP \
  --start-ip-address <your_ip> \
  --end-ip-address <your_ip>
```

### Storage Account の作成

```bash
az storage account create \
  --name sthandsonstorage \
  --resource-group rg-hands-on \
  --location japaneast \
  --sku Standard_LRS
```

### Function App の作成

```bash
az functionapp create \
  --resource-group rg-hands-on \
  --consumption-plan-location japaneast \
  --runtime node \
  --runtime-version 18 \
  --functions-version 4 \
  --name func-hands-on-app \
  --storage-account sthandsonstorage
```

### アプリケーション設定の追加

```bash
az functionapp config appsettings set \
  --name func-hands-on-app \
  --resource-group rg-hands-on \
  --settings \
    db_server="<yourserver>.database.windows.net" \
    db_database="hands_on_db" \
    db_user="<admin_user>" \
    db_password="<admin_password>"
```

---

## 付録B: 参考リンク

[1]: https://learn.microsoft.com/en-us/azure/azure-functions/functions-networking-options "Azure Functions のネットワークオプション"
[2]: https://learn.microsoft.com/en-us/azure/api-management/api-management-key-concepts "API Management の主要概念"
[3]: https://learn.microsoft.com/en-us/azure/azure-sql/database/firewall-configure?view=azuresql "Azure SQL Database のファイアウォール設定"
[4]: https://learn.microsoft.com/en-us/azure/frontdoor/best-practices "Azure Front Door のベストプラクティス"
[5]: https://learn.microsoft.com/en-us/azure/azure-functions/functions-develop-local "Azure Functions のローカル開発"
[6]: https://learn.microsoft.com/en-us/azure/api-management/rate-limit-policy "API Management のレート制限ポリシー"
[7]: https://learn.microsoft.com/en-us/azure-data-studio/quickstart-sql-database "Azure Data Studio クイックスタート"
[8]: https://learn.microsoft.com/en-us/azure/azure-functions/functions-premium-plan "Azure Functions Premium プラン"

---

## ライセンス

MIT License

---

## コントリビューション

このプロジェクトへの貢献を歓迎します。プルリクエストを送信する前に、[CONTRIBUTING.md](./CONTRIBUTING.md) をご確認ください。
