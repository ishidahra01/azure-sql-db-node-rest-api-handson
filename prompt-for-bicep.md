Bicepの定義ファイルを作って。

## 構成
[Internet Client / Browser / Mobile App]
↓
[Azure Front Door (WAF / Global routing)]
↓
[Azure API Management (認証, レート制御, 変換, ログ)]
↓
[Azure Functions (アプリ本体)]
↓
[Azure SQL Database (業務データ)]

## 要件
- 既存のFunctionsコードはデプロイ対象外（IaCはリソース定義のみ）
- APIMはDeveloper/Premiumを切替可能な apimSkuName パラメータ
- AFD: WAFポリシー、エンドポイント、オリジン＝APIM、ルールセットは最小
- SQL: サーバ＋DB作成。Public accessは既定で拒否。開発用途はallowedIpsで明示。Azureサービスからの接続は許可
- 可能なら将来のPrivate Link/PE統合のためのenablePrivateEndpoints（bool）