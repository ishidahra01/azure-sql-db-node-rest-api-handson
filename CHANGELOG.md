# 変更履歴 / Change Log

## v1.0.0 - ハンズオンコンテンツへの完全リニューアル

このリリースでは、既存のサンプルリポジトリを完全な Azure PaaS ハンズオンガイドに変換しました。

### 主な変更点

#### 1. ドキュメント

- **README.md**: 包括的な日本語ハンズオンガイドに完全刷新
  - 目的とゴールの明確化
  - フェーズ別アーキテクチャの説明
  - ステップバイステップの実施手順
  - トラブルシューティング
  - 将来の本番構成への拡張ガイド

- **QUICKSTART.md**: 5分で始められるクイックスタートガイドを追加
  - 最小限の手順で動作確認まで到達
  - よくあるエラーと解決策

- **BICEP_README.md**: Infrastructure as Code (IaC) ガイドを追加
  - Bicep テンプレートの使い方
  - パラメータの設定方法
  - デプロイ手順

- **sample-usage.md**: 日本語のサンプル使用方法に更新
  - ハンズオン用に簡素化
  - トラブルシューティング情報を追加

- **sql/README.md**: SQL セットアップスクリプトの説明を追加

#### 2. SQL スクリプト

- **sql/HandsOnSetup.sql**: ハンズオン用の簡素化された SQL スクリプトを作成
  - WideWorldImporters の依存を削除
  - 最小限の Customers テーブルとサンプルデータ
  - 2つのストアドプロシージャ（GetCustomerById、GetAllCustomers）
  - FOR JSON PATH による JSON レスポンス

- **sql/WideWorldImportersUpdates.sql**: 参考用として保持

#### 3. Azure Functions コード

- **customer/index.js**: ハンズオン用に簡素化
  - GET リクエストのみをサポート（PUT/PATCH/DELETE を削除）
  - ストアドプロシージャベースの呼び出しに簡素化
  - エラーハンドリングの改善
  - Content-Type ヘッダーの追加

- **customer/function.json**: GET メソッドのみに制限

#### 4. Infrastructure as Code

- **main.bicep**: Azure リソースの Bicep テンプレートを追加
  - Resource Group
  - Storage Account
  - Application Insights
  - App Service Plan (消費プラン)
  - Function App (Node.js 18, Linux)
  - Azure SQL Server
  - Azure SQL Database (Basic 層)
  - ファイアウォールルール

- **main.parameters.json.template**: パラメータテンプレートを追加

#### 5. デプロイスクリプト

- **azure-deploy.sh**: ハンズオン用に更新
  - リソース名を `rg-hands-on`、`func-hands-on-app` などに変更
  - リージョンを `japaneast` に変更
  - Functions ランタイムを v4、Node 18、Linux に更新
  - GitHub リポジトリ URL を更新

#### 6. 設定ファイル

- **local.settings.json.template**: わかりやすいプレースホルダーに更新
  - `<yourserver>` → より明確な指示
  - デフォルトのデータベース名を `hands_on_db` に

- **package.json**: プロジェクトメタデータを追加
  - 名前、バージョン、説明
  - `npm start` スクリプトの追加
  - キーワードの追加

- **.gitignore**: Bicep パラメータファイルを除外するように更新

### 削除されたもの

なし。既存のファイルはすべて保持され、必要に応じて更新されました。

### 技術的な改善

- **セキュリティ**: CodeQL スキャンで脆弱性なし
- **コード品質**: コードレビューを実施し、問題なし
- **互換性**: Node.js 18、Azure Functions v4 に対応
- **ドキュメント**: すべて日本語化、詳細な説明とリンクを追加

### 対応した機能要件

1. ✅ 完全な日本語ハンズオンガイドの作成
2. ✅ 簡素化された SQL スキーマとサンプルデータ
3. ✅ GET のみをサポートするシンプルな REST API
4. ✅ ローカル開発からクラウドデプロイまでの完全な手順
5. ✅ IaC (Bicep) のサンプルと説明
6. ✅ クイックスタートガイド
7. ✅ トラブルシューティング情報
8. ✅ 将来の本番構成へのロードマップ

### 次のステップ（今後の拡張候補）

- [ ] Terraform バージョンの IaC サンプル
- [ ] GitHub Actions による CI/CD パイプライン例
- [ ] API Management (APIM) 統合のサンプル
- [ ] Front Door 統合のサンプル
- [ ] Private Link / VNet 統合のサンプル
- [ ] 単体テストの追加
- [ ] 英語版ドキュメントの作成

### 参考リンク

- [元のリポジトリ](https://github.com/Azure-Samples/azure-sql-db-node-rest-api)
- [Azure Functions ドキュメント](https://learn.microsoft.com/ja-jp/azure/azure-functions/)
- [Azure SQL Database ドキュメント](https://learn.microsoft.com/ja-jp/azure/azure-sql/)
- [Bicep ドキュメント](https://learn.microsoft.com/ja-jp/azure/azure-resource-manager/bicep/)
