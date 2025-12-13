# 📋 デプロイメントサマリー: ネットワークアーキテクチャ更新

このドキュメントは、エンタープライズ構成のネットワークアーキテクチャ更新の概要と、デプロイ時に必要な手順をまとめたクイックリファレンスです。

## 🎯 更新内容の概要

### 主要な変更点

1. **Front Door → Application Gateway を Private Link 接続に変更**
   - インターネット露出の最小化
   - Azure バックボーンネットワーク経由の閉域接続

2. **Application Gateway に Private + Public IP を追加**
   - Private IP: 実際のトラフィック処理用
   - Public IP: Private Link 機能のための仕様上の要件

3. **TLS 終端を Application Gateway で実装**
   - 証明書管理の一元化
   - 内部通信は HTTP で簡素化

4. **通信プロトコルの最適化**
   - Internet → Front Door: HTTPS
   - Front Door → AppGW: HTTP (Private Link 経由)
   - AppGW 以降: HTTP (VNet内部)
   - Functions → SQL: TDS + TLS (必須)

---

## 🚀 クイックスタート: デプロイ手順

### 前提条件

- Azure CLI がインストールされている
- Azure Functions Core Tools v4 がインストールされている
- 適切な Azure サブスクリプションへのアクセス権限

### ステップ 1: パラメータファイルの準備

```bash
# テンプレートをコピー
cp main-enterprise.parameters.json.template main-enterprise.parameters.json

# 必須パラメータを編集
vim main-enterprise.parameters.json
```

**必須の編集項目**:
- `sqlAdminPassword`: 強力なパスワード
- `apimPublisherEmail`: 実際のメールアドレス
- `apimPublisherName`: 組織名

**オプション項目**（証明書を使用する場合のみ）:
- `tlsCertificateData`: Base64エンコードされた証明書
- `tlsCertificatePassword`: 証明書のパスワード

### ステップ 2: Azure へのデプロイ

```bash
# Azure にログイン
az login

# リソースグループを作成
az group create --name rg-handson-prod --location japaneast

# Bicep テンプレートをデプロイ
az deployment group create \
  --resource-group rg-handson-prod \
  --template-file main-enterprise.bicep \
  --parameters main-enterprise.parameters.json
```

**所要時間**: 約 60-90 分
- ネットワーク: 5-10 分
- Azure Firewall: 10-15 分
- Application Gateway: 10-15 分
- API Management Premium: 30-45 分
- Azure Front Door: 10-15 分
- Functions, SQL: 5-10 分

### ステップ 3: Private Link 接続の承認

デプロイ完了後、**必ず実行してください**:

```bash
# Azure Portal での手順:
# 1. Application Gateway のリソースを開く
# 2. Settings → Private Link を選択
# 3. Private endpoint connections タブ
# 4. Front Door からの接続要求を承認

# または Azure CLI で:
# 接続名を確認
az network application-gateway private-link list \
  --resource-group rg-handson-prod \
  --gateway-name appgw-handson-prod

# 承認
az network application-gateway private-link approve \
  --resource-group rg-handson-prod \
  --gateway-name appgw-handson-prod \
  --name <connection-name>
```

### ステップ 4: SQL スクリプトの実行

```bash
# Azure Portal で:
# 1. SQL Database を開く
# 2. Query Editor を選択
# 3. SQL 認証でログイン
# 4. sql/HandsOnSetup.sql を実行
```

### ステップ 5: Functions コードのデプロイ

```bash
# 依存パッケージをインストール
npm install

# Functions にデプロイ
func azure functionapp publish func-handson-prod
```

### ステップ 6: 動作確認

```bash
# Front Door のエンドポイント URL を取得
FRONTDOOR_URL=$(az deployment group show \
  --resource-group rg-handson-prod \
  --name main-enterprise \
  --query properties.outputs.frontDoorEndpointUrl.value -o tsv)

# API をテスト
curl "${FRONTDOOR_URL}/api/customer/123"
```

---

## 🔐 証明書のセットアップ（オプション）

証明書を使用する場合は、以下のいずれかの方法で準備してください。

### 方法 1: App Service Certificate（推奨）

1. Azure Portal で App Service Certificate を作成
2. ドメイン検証を完了
3. Key Vault にエクスポート
4. 証明書を Base64 エンコード
5. パラメータファイルに設定

詳細は [CERTIFICATE_GUIDE.md](CERTIFICATE_GUIDE.md) を参照してください。

### 方法 2: 自己署名証明書（開発環境のみ）

```bash
# 証明書を生成
openssl req -x509 -newkey rsa:4096 \
  -keyout appgw-key.pem -out appgw-cert.pem \
  -days 365 -nodes \
  -subj "/CN=api.example.local"

# PFX 形式に変換
openssl pkcs12 -export \
  -out appgw-cert.pfx \
  -inkey appgw-key.pem \
  -in appgw-cert.pem \
  -password pass:YourPassword123

# Base64 エンコード
base64 -i appgw-cert.pfx -o appgw-cert.b64

# パラメータファイルに設定
```

### 方法 3: 証明書なし（Front Door 既定ドメインのみ）

証明書パラメータを空のままにすると、以下の構成になります:
- Front Door が HTTPS 終端（`*.azurefd.net` ドメイン）
- Front Door → AppGW は HTTP（Private Link 経由）
- カスタムドメインは使用不可

---

## 📊 アーキテクチャ図

```
┌──────────────────────────────────────────────────────────────┐
│                         Internet                              │
│                            ↓ HTTPS                            │
│              (Azure Front Door 既定ドメイン)                  │
└──────────────────────────────────────────────────────────────┘
                               ↓
┌──────────────────────────────────────────────────────────────┐
│              Azure Front Door Premium                         │
│              - WAF, DDoS 保護                                 │
│              - グローバルロードバランシング                   │
└──────────────────────────────────────────────────────────────┘
                               ↓ Private Link (HTTP)
┌──────────────────────────────────────────────────────────────┐
│          Application Gateway WAF v2                           │
│          - Private IP: トラフィック処理用                     │
│          - Public IP: Private Link 仕様要件                   │
│          - TLS 終端 (証明書管理)                              │
└──────────────────────────────────────────────────────────────┘
                               ↓ HTTP (VNet内部)
┌──────────────────────────────────────────────────────────────┐
│             Azure Firewall Premium                            │
│             - IDPS 有効                                       │
│             - 侵入検知・防止                                  │
└──────────────────────────────────────────────────────────────┘
                               ↓ HTTP (VNet内部)
┌──────────────────────────────────────────────────────────────┐
│        API Management Premium (Internal VNet)                 │
│        - VNet 内部モード                                      │
│        - Private IP のみ                                      │
└──────────────────────────────────────────────────────────────┘
                               ↓ HTTPS (Private Endpoint)
┌──────────────────────────────────────────────────────────────┐
│         Azure Functions Premium (VNet統合)                    │
│         - ElasticPremium EP1                                  │
│         - パブリックアクセス無効                              │
└──────────────────────────────────────────────────────────────┘
                               ↓ TDS + TLS (Private Endpoint)
┌──────────────────────────────────────────────────────────────┐
│          Azure SQL Database                                   │
│          - パブリックアクセス完全無効                         │
│          - Private IP のみ                                    │
└──────────────────────────────────────────────────────────────┘
```

---

## ✅ デプロイ後のチェックリスト

- [ ] Front Door のエンドポイントが正常に作成されている
- [ ] Application Gateway の Private Link 接続が承認されている
- [ ] Application Gateway のヘルスチェックが正常
- [ ] Front Door 経由で API にアクセスできる
- [ ] HTTPS リダイレクトが動作している
- [ ] 証明書が正しく設定されている（使用する場合）
- [ ] Functions → SQL の接続が正常
- [ ] Application Insights でメトリクスが取得できている

---

## 🔍 トラブルシューティング

### Front Door から接続できない

**症状**: タイムアウト、503 エラー

**確認項目**:
1. Private Link 接続が承認されているか
2. Front Door のプロビジョニングが完了しているか（30-60分かかる）
3. Application Gateway のヘルスチェックが正常か

### 証明書エラー

**症状**: HTTPS リスナーが動作しない

**確認項目**:
1. 証明書が Base64 エンコードされているか
2. 証明書パスワードが正しいか
3. 証明書形式が PFX（PKCS#12）か

### SQL 接続エラー

**症状**: Functions から SQL に接続できない

**確認項目**:
1. SQL スクリプトが実行されているか
2. Private Endpoint が正しく構成されているか
3. Functions のアプリケーション設定が正しいか

---

## 📚 関連ドキュメント

- [README.md](README.md) - ハンズオン全体の概要
- [ARCHITECTURE.md](ARCHITECTURE.md) - アーキテクチャ詳細
- [ENTERPRISE_DEPLOYMENT.md](ENTERPRISE_DEPLOYMENT.md) - 詳細なデプロイ手順
- [CERTIFICATE_GUIDE.md](CERTIFICATE_GUIDE.md) - 証明書管理ガイド
- [NETWORK_ARCHITECTURE_UPDATE.md](NETWORK_ARCHITECTURE_UPDATE.md) - 更新内容の詳細

---

## 💰 コスト見積もり

**月額推定コスト**: 約 $4,000-5,000 (Japan East リージョン)

| サービス | SKU | 月額コスト（概算） |
|---------|-----|------------------|
| Azure Front Door | Premium | ~$330 |
| Application Gateway | WAF v2 (2 instances) | ~$250 |
| Azure Firewall | Premium | ~$900 |
| API Management | Premium (1 unit) | ~$3,000 |
| Azure Functions | Premium EP1 | ~$150 |
| Azure SQL Database | Basic | ~$5 |
| Storage Account | Standard LRS | ~$5 |
| Application Insights | - | ~$10 |

> **注意**: トラフィック量、データ転送量により変動します。

---

## 🧹 クリーンアップ

リソースが不要になった場合:

```bash
# リソースグループごと削除
az group delete --name rg-handson-prod --yes --no-wait
```

> **警告**: この操作は取り消せません。削除前に必要なデータをバックアップしてください。

---

## 📞 サポート

問題が発生した場合は、以下を確認してください:

1. Azure Portal で各リソースのステータスを確認
2. Application Insights でエラーログを確認
3. Azure Monitor でメトリクスを確認
4. [ENTERPRISE_DEPLOYMENT.md](ENTERPRISE_DEPLOYMENT.md) のトラブルシューティングセクションを参照

---

このガイドが、エンタープライズ構成のデプロイに役立つことを願っています。
