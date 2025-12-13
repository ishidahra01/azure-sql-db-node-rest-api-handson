# 🏗️ アーキテクチャ詳細ガイド

このドキュメントでは、各学習パスのアーキテクチャ構成と設計思想を詳しく説明します。

## 📊 アーキテクチャの進化

### パス1: クイックスタート（最小構成）

```
[開発端末 (localhost:7071)]
    ↓ TLS 1.2+
[Azure SQL Database]
    - パブリックアクセス: 開発端末IPのみ許可
    - ファイアウォールルール設定必須
```

**特徴**:
- ✅ 最速で動作確認可能（30分）
- ✅ ローカル開発環境で完結
- ✅ コスト: SQL Database のみ（~$5/月）
- ❌ 本番利用不可

**使用リソース**:
- Azurite (ローカルストレージエミュレータ)
- Azure SQL Database (クラウド)
- Azure Functions Core Tools (ローカル実行)

---

### パス2: 標準ハンズオン（基本構成）

```
[Internet / curl]
    ↓ HTTPS
[Azure Functions (消費プラン)]
    ↓ TLS 1.2+
[Azure SQL Database]
    - ファイアウォールルール: Functions送信IP許可
```

**特徴**:
- ✅ クラウド上で動作する最小構成
- ✅ 低コスト（従量課金）
- ✅ パブリックアクセス可能
- ❌ セキュリティレベルは基本的
- ❌ スケーラビリティに制限

**使用リソース**:
- Azure Functions (消費プラン Y1)
- Azure SQL Database (Basic)
- Storage Account (Functions用)
- Application Insights (監視)

**コスト**: 約 $10-20/月

---

### パス3: 本番構成（Front Door + APIM）

```
[Internet]
    ↓ HTTPS
[Azure Front Door Premium]
    - WAF, DDoS保護
    - グローバル負荷分散
    ↓ HTTPS
[API Management (Developer/Premium)]
    - 認証、レート制御
    - API管理
    ↓ HTTPS
[Azure Functions (消費プラン)]
    ↓ TLS 1.2+
[Azure SQL Database]
    - ファイアウォールルール: 0.0.0.0 (Azure services)
```

**特徴**:
- ✅ グローバル配信とWAF保護
- ✅ API管理とポリシー適用
- ✅ 認証、レート制御、監視
- ⚠️ 一部パブリックアクセス
- ⚠️ コストが高め

**使用リソース**:
- Azure Front Door Premium
- API Management (Developer or Premium)
- Azure Functions (消費プラン)
- Azure SQL Database (Basic)
- Storage Account
- Application Insights

**コスト**: 
- Developer: 約 $400/月
- Premium: 約 $3,700/月

---

### パス4: エンタープライズ構成（完全閉域）

```
[Internet]
    ↓ HTTPS
[Azure Front Door Premium]
    - WAF, DDoS保護, Premium機能
    ↓ Private Link (将来対応) / Public IP
[Application Gateway WAF v2]
    - WAF OWASP 3.2
    - リージョナルロードバランサー
    ↓ HTTP (VNet内部)
[Azure Firewall Premium]
    - IDPS有効
    - 侵入検知・防止
    ↓ HTTP (VNet内部)
[API Management Premium (Internal VNet)]
    - VNet内部モード
    - Private IP のみ
    ↓ HTTPS (Private Endpoint)
[Azure Functions Premium (VNet統合)]
    - ElasticPremium EP1
    - パブリックアクセス無効
    ↓ TLS 1.2+ (Private Endpoint)
[Azure SQL Database (Private Endpoint)]
    - パブリックアクセス完全無効
    - Private IP のみ
```

**特徴**:
- ✅ 完全閉域ネットワーク構成
- ✅ Private Endpoint による全接続
- ✅ Azure Firewall Premium (IDPS有効)
- ✅ 多層防御アーキテクチャ
- ✅ 本番環境レベルのセキュリティ
- ⚠️ 高コスト
- ⚠️ デプロイ時間が長い (60-90分)

**使用リソース**:
- Azure Front Door Premium
- Application Gateway WAF v2
- Azure Firewall Premium
- API Management Premium (Internal VNet)
- Azure Functions Premium (EP1)
- Azure SQL Database (Basic or Standard)
- Virtual Network + Subnets (5サブネット)
- Network Security Groups (5個)
- Private Endpoints (3個)
- Private DNS Zones (3個)
- Storage Account
- Application Insights

**コスト**: 約 $4,000-5,000/月

---

## 🔐 セキュリティレイヤーの比較

| セキュリティ機能 | パス1 | パス2 | パス3 | パス4 |
|---------------|------|------|------|------|
| **TLS暗号化** | ✅ | ✅ | ✅ | ✅ |
| **SQLファイアウォール** | ✅ | ✅ | ✅ | N/A (Private) |
| **WAF保護** | ❌ | ❌ | ✅ | ✅✅ (2層) |
| **DDoS保護** | ❌ | ❌ | ✅ | ✅ |
| **IDPS (侵入検知)** | ❌ | ❌ | ❌ | ✅ |
| **Private Endpoint** | ❌ | ❌ | ❌ | ✅ (全接続) |
| **VNet統合** | ❌ | ❌ | ❌ | ✅ |
| **パブリックアクセス** | 制限付き | 制限付き | 一部 | Front Doorのみ |
| **API管理** | ❌ | ❌ | ✅ | ✅ |
| **認証・認可** | ❌ | ❌ | ✅ | ✅ |

---

## 🌐 ネットワーク設計（パス4詳細）

### VNet構成

```
VNet: 10.0.0.0/16
├── ApplicationGatewaySubnet: 10.0.1.0/24
│   ├── Application Gateway WAF v2
│   └── Public IP (インターネット受付用)
│
├── AzureFirewallSubnet: 10.0.2.0/24
│   ├── Azure Firewall Premium
│   └── Public IP (管理用)
│
├── ApiManagementSubnet: 10.0.3.0/24
│   ├── API Management (Internal mode)
│   ├── Delegation: Microsoft.ApiManagement/service
│   └── Private IP: 10.0.3.x
│
├── FunctionsSubnet: 10.0.4.0/24
│   ├── Functions VNet統合用
│   ├── Delegation: Microsoft.Web/serverFarms
│   └── 送信トラフィック用
│
└── PrivateEndpointSubnet: 10.0.5.0/24
    ├── Functions Private Endpoint
    ├── SQL Database Private Endpoint
    └── Private DNS統合
```

### トラフィックフロー

**インバウンド（リクエスト）**:
1. Internet → Front Door (HTTPS, グローバルエッジ)
2. Front Door → Application Gateway (HTTP over Private Link/Public IP)
3. Application Gateway → Azure Firewall (HTTP, 10.0.2.x)
4. Azure Firewall → API Management (HTTP, 10.0.3.x)
5. API Management → Functions Private Endpoint (HTTPS, 10.0.5.x)
6. Functions → SQL Private Endpoint (TLS, 10.0.5.y)

**アウトバウンド（レスポンス）**:
- 同じ経路を逆方向

### NSG（ネットワークセキュリティグループ）

**ApplicationGatewaySubnet NSG**:
- Inbound: GatewayManager (65200-65535)
- Inbound: HTTPS (443) from Internet
- Inbound: AzureLoadBalancer

**AzureFirewallSubnet NSG**:
- (Firewall自体が制御)

**ApiManagementSubnet NSG**:
- Inbound: APIM Management Endpoint (3443)
- Inbound: HTTPS (443) from VirtualNetwork
- Inbound: HTTP (80) from VirtualNetwork
- Inbound: AzureLoadBalancer

**FunctionsSubnet NSG**:
- (Delegation により Functions が制御)

**PrivateEndpointSubnet NSG**:
- Private Endpoint Network Policies: Disabled

---

## 🔄 通信プロトコルの選択理由

### なぜ Application Gateway 以降を HTTP にするのか？

**理由1: 証明書管理の複雑さ回避**
- Application Gateway で TLS 終端（HTTPS → HTTP変換）
- 内部通信は HTTP で簡素化
- 証明書更新は Application Gateway のみで管理

**理由2: VNet内部は物理的に分離されている**
- Azure VNet は論理的に完全分離
- 他のテナントからアクセス不可
- 内部通信は Azure バックボーンネットワークで保護

**理由3: パフォーマンス向上**
- TLS ハンドシェイクのオーバーヘッド削減
- 内部通信の高速化

**代替案: 完全HTTPS化**
- より厳格なセキュリティ要件の場合
- Application Gateway → Firewall: HTTPS
- Firewall → APIM: HTTPS
- 証明書管理の自動化が必要（Key Vault統合など）

---

## 📈 スケーラビリティと可用性

### パス2（基本構成）

**スケーリング**:
- Functions: 自動スケール（消費プラン）
- SQL: 手動スケールアップ/ダウン

**可用性**:
- Functions: シングルインスタンス（コールドスタート有）
- SQL: 単一リージョン、自動バックアップ
- SLA: 99.9%（各サービス個別）

**制限**:
- 同時実行数: 200インスタンス（消費プラン）
- 実行時間: 5分（HTTP）、10分（その他）

### パス3（本番構成）

**スケーリング**:
- Front Door: グローバル自動スケール
- APIM: 手動スケール（Premium: マルチリージョン可）
- Functions: 自動スケール（制限拡大可能）
- SQL: 手動スケール

**可用性**:
- Front Door: 99.99%
- APIM Premium: 99.99%（マルチリージョン）
- Functions: 99.95%（消費プラン）
- SQL: 99.99%（Business Critical）

### パス4（エンタープライズ構成）

**スケーリング**:
- Front Door: グローバル自動スケール
- Application Gateway: 自動スケール（v2）
- Firewall: 手動スケール（インスタンス数）
- APIM Premium: 手動スケール
- Functions Premium: 自動スケール（事前ウォーム可能）
- SQL: 手動スケール

**可用性**:
- Front Door: 99.99%
- Application Gateway v2: 99.95%
- Azure Firewall Premium: 99.95%
- APIM Premium: 99.99%
- Functions Premium: 99.95%
- SQL Standard: 99.99%

**冗長化オプション**:
- マルチリージョンデプロイ（フェイルオーバー）
- SQL フェイルオーバーグループ
- ゾーン冗長（各サービスで対応）

---

## 💰 コスト最適化のヒント

### 開発環境でコストを抑える

**パス3での工夫**:
- APIM: Developer SKU を使用（$60/月）
- Functions: 消費プランのまま（従量課金）
- SQL: Basic または Serverless
- Front Door: 開発時は無効化も検討

**パス4での工夫**:
- 開発時は一部リソースをスキップ
  - Azure Firewall → NSG のみで代替
  - Application Gateway → 削除してFront Door直結
- 使用しない時はリソースを停止
  - APIM: スケールを0にはできないが、インスタンス数を最小に
  - Functions Premium: Always On を無効化

### 本番環境でのコスト最適化

**リザーブドインスタンス**:
- Azure Firewall: 1年または3年契約で最大65%割引
- SQL Database: vCore ライセンスで割引

**スケーリングポリシー**:
- Functions: コールドスタート許容できる場合は消費プラン
- APIM: トラフィック予測に基づいてスケール
- SQL: 使用率に応じて適切なSKU選択

---

## 🎯 各パスの選択ガイド

### パス1を選ぶべき場合
- ✅ とにかく早く動作確認したい
- ✅ ローカル開発のみ
- ✅ Azure の基礎を学びたい
- ❌ 本番デプロイは不要

### パス2を選ぶべき場合
- ✅ Azure PaaS の基本を理解したい
- ✅ 低コストでクラウド体験
- ✅ プロトタイプ開発
- ❌ 本番環境には不向き

### パス3を選ぶべき場合
- ✅ 本番環境を想定した構成
- ✅ API 管理が必要
- ✅ グローバル配信とWAF
- ⚠️ コストは中〜高

### パス4を選ぶべき場合
- ✅ エンタープライズレベルのセキュリティ
- ✅ 完全閉域ネットワーク
- ✅ コンプライアンス要件が厳しい
- ✅ IDPS (侵入検知・防止) が必須
- ⚠️ 高コスト、長いデプロイ時間

---

## 📚 参考: Azure サービスの選択理由

### なぜ Azure Front Door？
- ✅ グローバルロードバランシング
- ✅ WAF と DDoS 保護
- ✅ TLS 終端とカスタムドメイン
- ✅ キャッシュと配信最適化

**代替案**: Azure Application Gateway（リージョナル）、Azure CDN

### なぜ API Management？
- ✅ API のライフサイクル管理
- ✅ 認証・認可の一元化
- ✅ レート制限とクォータ
- ✅ 開発者ポータル

**代替案**: Azure API Gateway（プレビュー）、独自APIゲートウェイ

### なぜ Azure Firewall Premium？
- ✅ IDPS（侵入検知・防止）
- ✅ TLS インスペクション
- ✅ URL フィルタリング
- ✅ 脅威インテリジェンス

**代替案**: ネットワーク仮想アプライアンス（NVA）、サードパーティファイアウォール

### なぜ Application Gateway？
- ✅ リージョナルロードバランサー
- ✅ WAF v2 (OWASP ルール)
- ✅ TLS 終端
- ✅ パスベースルーティング

**代替案**: Azure Load Balancer + 独自WAF

---

## 🔗 関連ドキュメント

- [README.md](README.md) - ハンズオン全体の概要
- [QUICKSTART.md](QUICKSTART.md) - パス1: クイックスタート
- [BICEP_README.md](BICEP_README.md) - パス3: 本番構成
- [ENTERPRISE_DEPLOYMENT.md](ENTERPRISE_DEPLOYMENT.md) - パス4: エンタープライズ構成
- [ハンズオンTips.md](ハンズオンTips.md) - 設計のベストプラクティス

---

## ❓ よくある質問

**Q: パス4は本当に必要ですか？**

A: セキュリティ要件次第です。以下の要件がある場合はパス4を推奨:
- 金融、医療、政府系システム
- 個人情報を扱うシステム
- コンプライアンス要件（PCI-DSS、HIPAA等）
- 完全閉域ネットワークが必須

**Q: パス3とパス4の最大の違いは？**

A: パス3は「パブリックアクセス制限」、パス4は「完全閉域化」です:
- パス3: Functions と SQL にはインターネットから（制限付きで）アクセス可能
- パス4: Functions と SQL は Private Endpoint のみ、インターネットから完全遮断

**Q: HTTP 通信は本当に安全ですか？**

A: VNet 内部の HTTP 通信は以下の理由で安全です:
- Azure VNet は物理的・論理的に分離
- 他のテナントからアクセス不可
- Azure バックボーンネットワークで保護
- ただし、より厳格な要件がある場合は HTTPS 化を検討

**Q: コストを抑えつつセキュリティを高めるには？**

A: 段階的アプローチを推奨:
1. まずパス3で構築（APIM Developer）
2. Private Endpoint を段階的に追加（SQL → Functions）
3. 必要に応じて Firewall と Application Gateway を追加
4. トラフィックが増えたら APIM を Premium に

---

このアーキテクチャガイドが、あなたのプロジェクトに最適な構成を選択する助けになれば幸いです。
