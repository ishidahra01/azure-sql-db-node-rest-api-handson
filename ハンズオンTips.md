# 💡 Azure PaaS ハンズオン拡張ドキュメント（上級者向け）

> **このドキュメントの対象者**: 実務で Azure PaaS を設計・運用する方、設計論点を深く理解したい方  
> **推奨タイミング**: パス2またはパス3を完了した後  
> **目的**: 設計のベストプラクティス、よくある論点と解決策、実務のTipsを学ぶ

この文書は、Azure Functions + Azure SQL REST API ハンズオン教材をベースに、設計のポイント、よくある論点と解決策、IaC（Bicep/Terraform）やコーディングエージェント活用のTipsなど、実務で役立つ知見をまとめたものです。ハンズオンで用意した簡単な構成を実際のプロダクション構成に発展させる際の指針として利用してください。

## 1. 設計の観点とベストプラクティス

### 1.1 Azure Functions

- **ホスティングプランの選定**  
  Functions には従量課金の「Flex Consumption」や Premium、Dedicated など複数のプランがあります。  
  初期は消費プランで構成しても良いですが、コールドスタートを抑えたり VNet 統合が必要な場合は Premium や Dedicated を検討します。  
  詳細: [Microsoft Learn – Best practices for reliable Azure Functions](https://learn.microsoft.com/en-us/azure/azure-functions/functions-best-practices)

- **接続管理（SQL / 外部API）**  
  Function ごとに `SqlConnection` を都度生成せず、**静的クライアントを再利用**するのが推奨です。  
  `SqlClient` を static に保持し、接続プールを活かすことでスループットを改善できます。  
  詳細: [Manage connections in Azure Functions](https://learn.microsoft.com/en-us/azure/azure-functions/manage-connections)

- **並列実行設計**  
  同時実行が多い場合、キューを介した非同期処理（Azure Queue Storage / Service Bus）を検討します。HTTP トリガーを多重化するとスロットリングが起きるため、処理の分離と監視を組み合わせることが重要です。

- **監視と運用**  
  Application Insights を必ず有効化し、依存関係のトレース、失敗率、Cold Start 時間を観測します。  
  Premium 以上であれば専用プランのスケール制御も可能。

---

### 1.2 Azure SQL Database

- **ネットワーク設計**  
  - 開発環境ではパブリックアクセスを許可しても良いが、本番では **Private Link** を利用。  
  - SQL Server の “Allow Azure Services” を無効にし、Private Endpoint 経由のみ許可する。  
  - 詳細: [Azure Private Link for Azure SQL Database](https://learn.microsoft.com/en-us/azure/azure-sql/database/private-endpoint-overview)

- **接続管理**  
  - Connection Pool を活用。アプリ側ではトランザクション後すぐに接続を閉じる。  
  - Azure Functions 側では再利用（上記参照）。  
  - 接続タイムアウトは 15～30 秒を推奨。

- **冗長化・可用性**  
  - **ゾーン冗長**: Business Critical / Premium tiers で有効。  
  - **リージョン冗長**: フェイルオーバーグループを構成。  
  - 詳細: [Azure SQL Database Well-Architected Guide](https://learn.microsoft.com/en-us/azure/well-architected/service-guides/azure-sql-database)

---

### 1.3 Azure API Management (APIM)

- **API 管理の中核**  
  認証・レート制御・変換・ログをコードから切り離し、ポリシーで集中管理。  
  - `rate-limit-by-key` ポリシーを利用して利用者ごとのリクエスト制限を実装。  
  - Developer Portal で API 仕様（Swagger / OpenAPI）を自動公開。  
  詳細: [Azure API Management rate-limit policy](https://learn.microsoft.com/en-us/azure/api-management/rate-limit-policy)

- **閉域構成時の注意点**  
  - Internal モードで VNet に統合。  
  - Front Door → APIM 間は Private Endpoint 経由。  
  - Functions は VNet 統合。SQL は Private Link 経由。

---

### 1.4 Azure Front Door

- **役割**: グローバルエントリポイント＋WAF＋CDN。  
  - WAF ルールで SQLi / XSS を防御。  
  - TLS 終端＋パスルーティング＋フェイルオーバー。  
  - APIM または Function App をオリジンとして登録。  
  詳細: [Best Practices - Azure Front Door](https://learn.microsoft.com/en-us/azure/frontdoor/best-practices)

- **ベストプラクティス**
  - 複数リージョン構成では、Health Probe による自動フェイルオーバー設定を必須化。  
  - キャッシュを多用する場合は動的コンテンツとの分離を考慮。  
  - WAF ログを Log Analytics に送信し、アラートルールを定義。

---

## 2. IaC（Infrastructure as Code）実践ポイント

### 2.1 Bicep / Terraform の使い分け

| 観点 | Bicep | Terraform |
|------|--------|------------|
| Azure ネイティブ統合 | ◎ ARM との互換性が高い | ○ azurerm プロバイダ依存 |
| マルチクラウド対応 | ✕ | ◎ |
| 学習コスト | 低 | やや高 |
| CI/CD 連携 | Azure DevOps / GitHub Actions 向けが充実 | 各種ツール対応豊富 |

> 推奨: Azure 専用プロジェクトでは **Bicep** を採用。将来的なクラウド移植性を考える場合は Terraform。

### 2.2 GitHub Copilot 活用例

```bicep
// Azure Functions と Azure SQL Database を作成する Bicep テンプレート
// - 消費プラン Function App
// - Basic 層 SQL Database
// - Application Insights による監視
````

上記コメントを入力するだけで、Copilot が自動的にリソース定義を提案してくれます。
生成されたコードは構文検証 (`az bicep build`) と `what-if` で必ず確認。

---

## 3. よくある論点と対処法

| 論点                    | 原因 / 背景             | 解決策                                         |
| --------------------- | ------------------- | ------------------------------------------- |
| Functions → SQL 接続エラー | IP 許可漏れ / VNet 統合ミス | SQL Server の Firewall 設定を確認、Private Linkを使用 |
| Cold Start が遅い        | 消費プランのスケールアウト遅延     | Premium プランに移行、Always Ready を設定             |
| IaC デプロイ時エラー          | 名前重複 / IP形式不正       | `projectName` パラメータ変更、IPv4形式を確認             |
| API 呼び出しのレート超過        | 利用者のリクエスト集中         | `rate-limit-by-key` ポリシーを設定                 |
| SQL パフォーマンス低下         | 同時接続増加 / 非効率クエリ     | 接続プール有効化・クエリ最適化 / インデックス設計見直し               |

---

## 4. 高可用性と冗長化設計の原則

Azure Well-Architected Framework に基づく信頼性設計の基本指針：

* **ゾーン冗長**: 単一リージョン内での耐障害性。
  SQL: Business Critical / Premium で対応。
  Functions: Premium 以上で対応。
* **リージョン冗長**: 複数リージョン配置。Front Door + フェイルオーバーグループで実現。
* **データ整合性**: フェイルオーバー時は Azure SQL Database のセカンダリ同期遅延を監視。
* **監視と復旧性**: Application Insights + Azure Monitor + Log Analytics に統合。

---

## 5. まとめ

このハンズオンの発展形では、以下を意識して構築することで、本番運用レベルの PaaS アーキテクチャを実現できます。

1. コード・インフラ・構成をすべて宣言的に管理（IaC）
2. Functions の接続・スケーリング設計を明示
3. SQL は Private Link で閉域化
4. Front Door / APIM でセキュリティと公開制御を一元化
5. Application Insights / Monitor で可観測性を確保

---