# SQL セットアップスクリプト

このディレクトリには、Azure SQL Database でハンズオンを実行するために必要な SQL スクリプトが含まれています。

## ファイル

### HandsOnSetup.sql

ハンズオン用の最小限のスキーマとサンプルデータを作成するスクリプトです。

このスクリプトには以下が含まれています：

- **Customers テーブル**: 顧客情報を格納するテーブル
- **サンプルデータ**: テスト用の顧客データ（CustomerID: 123, 124）
- **GetCustomerById ストアドプロシージャ**: 指定した ID の顧客情報を JSON で返す
- **GetAllCustomers ストアドプロシージャ**: すべての顧客情報を JSON で返す

## 使い方

1. Azure Portal で Azure SQL Database を開きます
2. 「Query editor (preview)」を開きます
3. データベースの管理者資格情報でログインします
4. `HandsOnSetup.sql` の内容をコピーして貼り付けます
5. 「Run」ボタンをクリックしてスクリプトを実行します

または、Azure Data Studio や SQL Server Management Studio (SSMS) を使用してスクリプトを実行することもできます。

## 確認

スクリプトの実行後、以下のクエリでデータを確認できます：

```sql
SELECT * FROM dbo.Customers;
```

ストアドプロシージャのテスト：

```sql
EXEC dbo.GetCustomerById @CustomerID = 123;
```

結果は JSON 形式で返されます。

## WideWorldImportersUpdates.sql（参考）

このファイルは、WideWorldImporters サンプルデータベースを使用する場合のスクリプトです。
このハンズオンでは使用しませんが、より複雑な例を試したい場合の参考として残しています。
