# 🔐 証明書管理ガイド

このガイドでは、Application Gateway の TLS 終端に使用する証明書の準備と管理方法を説明します。

## 📋 証明書の役割

### エンタープライズ構成での証明書配置

```
[Internet]
    ↓ HTTPS (Front Door 既定証明書 *.azurefd.net - 管理不要)
[Azure Front Door Premium]
    ↓ HTTP over Private Link (閉域トンネル内)
[Application Gateway]
    ↓ TLS 終端 (証明書必要) ← このガイドの対象
    ↓ HTTP (VNet内部)
[以降のコンポーネント]
```

### 証明書が必要な理由

1. **TLS 終端の実装**: Application Gateway で HTTPS を HTTP に変換
2. **証明書管理の一元化**: 証明書は AppGW のみで管理、内部は HTTP で簡素化
3. **カスタムドメイン**: 独自ドメインで API を公開する場合に必要

### 証明書が不要なケース

- Front Door の既定ドメイン（`*.azurefd.net`）のみで運用する場合
- 開発環境やテスト環境で HTTP のままで問題ない場合

この場合、Front Door が HTTPS 終端し、AppGW には HTTP でフォワードします。

---

## 🎯 証明書の選択肢

### 方法 1: App Service Certificate（推奨 - 本番環境）

**メリット**:
- ✅ Azure が証明書の更新を自動管理
- ✅ Key Vault と統合
- ✅ 信頼された CA が発行

**デメリット**:
- ⚠️ コストがかかる（年間 $75 程度）
- ⚠️ ドメインの所有権確認が必要

**適用ケース**: 本番環境、カスタムドメインを使用する場合

### 方法 2: Let's Encrypt（無料）

**メリット**:
- ✅ 無料
- ✅ 信頼された CA が発行

**デメリット**:
- ⚠️ 90日ごとに手動更新が必要（自動化可能）
- ⚠️ Azure との統合が手動

**適用ケース**: コストを抑えたい場合、自動更新スクリプトを構築できる場合

### 方法 3: 自己署名証明書

**メリット**:
- ✅ 完全に無料
- ✅ すぐに作成可能

**デメリット**:
- ❌ ブラウザで警告が表示される
- ❌ 本番環境では使用不可

**適用ケース**: 開発環境、内部テストのみ

### 方法 4: Front Door 既定ドメインのみ（証明書不要）

**メリット**:
- ✅ 証明書管理が不要
- ✅ Front Door が HTTPS を提供

**デメリット**:
- ⚠️ カスタムドメインは使用不可
- ⚠️ `*.azurefd.net` ドメインのみ

**適用ケース**: カスタムドメインが不要な場合、内部システム

---

## 📝 方法 1: App Service Certificate の作成と設定

### Step 1: App Service Certificate の作成

Azure Portal での作成:

1. Azure Portal で "App Service Certificates" を検索
2. **+ Create** をクリック
3. 以下の情報を入力:
   - **Subscription**: サブスクリプションを選択
   - **Resource Group**: 既存のリソースグループを選択
   - **Name**: 証明書の名前（例: `appgw-cert-prod`）
   - **Naked Domain Host Name**: ドメイン名（例: `api.example.com`）
   - **Certificate Type**: Standard または Wildcard
4. **Review + Create** → **Create**

### Step 2: ドメインの検証

証明書を作成すると、ドメイン所有権の確認が必要です。

**方法 A: DNS 検証（推奨）**:
1. 証明書のリソースを開く
2. **Configuration** → **Verify Domain**
3. DNS TXT レコードを追加するよう指示される
4. DNS プロバイダーで TXT レコードを追加
5. **Verify** をクリック

**方法 B: HTTP 検証**:
1. 指定されたファイルをドメインのルートに配置
2. `http://yourdomain.com/.well-known/pki-validation/<file>` でアクセス可能にする
3. **Verify** をクリック

### Step 3: Key Vault へのエクスポート

証明書を Key Vault にエクスポートします。

```bash
# App Service Certificate を Key Vault にエクスポート
az appservice cert show \
  --resource-group rg-handson-prod \
  --name appgw-cert-prod

# Key Vault シークレットとして保存される
# Key Vault 名を確認
```

### Step 4: 証明書を Bicep で使用

**オプション A: Key Vault から直接参照（推奨）**:

```bicep
// Key Vault 参照
resource keyVault 'Microsoft.KeyVault/vaults@2023-02-01' existing = {
  name: 'kv-handson-prod'
  scope: resourceGroup()
}

resource appGwCert 'Microsoft.Network/applicationGateways@2023-05-01' = {
  // ...
  properties: {
    sslCertificates: [
      {
        name: 'appgw-ssl-cert'
        properties: {
          keyVaultSecretId: '${keyVault.properties.vaultUri}secrets/appgw-cert-prod'
        }
      }
    ]
  }
}
```

**オプション B: パラメータで証明書データを渡す**:

```bash
# 証明書を PFX 形式でダウンロード
az keyvault secret download \
  --vault-name kv-handson-prod \
  --name appgw-cert-prod \
  --file appgw-cert.pfx \
  --encoding base64

# Base64 エンコード
CERT_DATA=$(base64 -i appgw-cert.pfx)

# パラメータファイルに設定
# main-enterprise.parameters.json
{
  "tlsCertificateData": {
    "value": "<Base64エンコードされた証明書データ>"
  },
  "tlsCertificatePassword": {
    "value": "<証明書のパスワード>"
  }
}
```

---

## 🛠️ 方法 2: 自己署名証明書の作成（開発環境のみ）

### OpenSSL を使用した証明書作成

```bash
# 1. 秘密鍵と証明書を生成
openssl req -x509 -newkey rsa:4096 \
  -keyout appgw-key.pem \
  -out appgw-cert.pem \
  -days 365 -nodes \
  -subj "/C=JP/ST=Tokyo/L=Tokyo/O=Example/CN=api.example.local"

# 2. PFX 形式に変換（Application Gateway で使用）
openssl pkcs12 -export \
  -out appgw-cert.pfx \
  -inkey appgw-key.pem \
  -in appgw-cert.pem \
  -password pass:YourPassword123

# 3. Base64 エンコード
base64 -i appgw-cert.pfx -o appgw-cert.b64

# 4. エンコードされたデータを表示
cat appgw-cert.b64
```

### パラメータファイルへの設定

```json
{
  "tlsCertificateData": {
    "value": "<appgw-cert.b64 の内容をコピー>"
  },
  "tlsCertificatePassword": {
    "value": "YourPassword123"
  }
}
```

### デプロイ

```bash
az deployment group create \
  --resource-group rg-handson-prod \
  --template-file main-enterprise.bicep \
  --parameters main-enterprise.parameters.json
```

---

## 🔄 証明書の更新

### App Service Certificate の自動更新

App Service Certificate は自動更新されます:
- 有効期限の 30 日前に自動更新
- Key Vault に保存された証明書も自動更新される
- Application Gateway に Managed Identity を設定すれば自動反映

### 手動更新が必要な場合

Let's Encrypt や自己署名証明書の場合:

```bash
# 1. 新しい証明書を生成
# 2. Key Vault に新しい証明書をアップロード
az keyvault certificate import \
  --vault-name kv-handson-prod \
  --name appgw-cert-prod \
  --file new-cert.pfx

# 3. Application Gateway を再デプロイまたは手動更新
az network application-gateway ssl-cert update \
  --resource-group rg-handson-prod \
  --gateway-name appgw-handson-prod \
  --name appgw-ssl-cert \
  --cert-file new-cert.pfx \
  --cert-password YourPassword123
```

---

## 🔐 セキュリティのベストプラクティス

### 1. Key Vault で証明書を管理

```bicep
// Managed Identity を使用して Key Vault にアクセス
resource appGw 'Microsoft.Network/applicationGateways@2023-05-01' = {
  name: appGwName
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    sslCertificates: [
      {
        name: 'appgw-ssl-cert'
        properties: {
          keyVaultSecretId: keyVaultSecretId
        }
      }
    ]
  }
}

// Key Vault のアクセスポリシー
resource keyVaultAccessPolicy 'Microsoft.KeyVault/vaults/accessPolicies@2023-02-01' = {
  parent: keyVault
  name: 'add'
  properties: {
    accessPolicies: [
      {
        tenantId: subscription().tenantId
        objectId: appGw.identity.principalId
        permissions: {
          secrets: [
            'get'
          ]
          certificates: [
            'get'
          ]
        }
      }
    ]
  }
}
```

### 2. パラメータファイルの保護

```bash
# パラメータファイルを Git にコミットしない
echo "*.parameters.json" >> .gitignore

# 本番環境ではパラメータをファイルに保存せず、コマンドラインで指定
az deployment group create \
  --resource-group rg-handson-prod \
  --template-file main-enterprise.bicep \
  --parameters \
    sqlAdminPassword="$SQL_PASSWORD" \
    tlsCertificateData="$CERT_DATA" \
    tlsCertificatePassword="$CERT_PASSWORD"
```

### 3. 証明書の有効期限監視

```bash
# Azure Monitor でアラートを設定
az monitor metrics alert create \
  --name cert-expiry-alert \
  --resource-group rg-handson-prod \
  --scopes /subscriptions/.../applicationGateways/appgw-handson-prod \
  --condition "avg SslCertificateExpiry < 30" \
  --description "SSL certificate expires in less than 30 days"
```

---

## 🔗 Bicep での証明書統合

### 完全な例: Key Vault 統合

```bicep
// Key Vault の作成
resource keyVault 'Microsoft.KeyVault/vaults@2023-02-01' = {
  name: 'kv-${projectName}-${env}'
  location: location
  properties: {
    tenantId: subscription().tenantId
    sku: {
      family: 'A'
      name: 'standard'
    }
    enabledForDeployment: true
    enabledForTemplateDeployment: true
  }
}

// Application Gateway with Managed Identity
resource appGw 'Microsoft.Network/applicationGateways@2023-05-01' = {
  name: appGwName
  location: location
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    sslCertificates: [
      {
        name: 'appgw-ssl-cert'
        properties: {
          keyVaultSecretId: '${keyVault.properties.vaultUri}secrets/appgw-cert'
        }
      }
    ]
    // ... その他の設定
  }
}

// Key Vault アクセスポリシー
resource keyVaultAccessPolicy 'Microsoft.KeyVault/vaults/accessPolicies@2023-02-01' = {
  parent: keyVault
  name: 'add'
  properties: {
    accessPolicies: [
      {
        tenantId: subscription().tenantId
        objectId: appGw.identity.principalId
        permissions: {
          secrets: ['get']
          certificates: ['get']
        }
      }
    ]
  }
}
```

---

## 📚 参考リンク

- [App Service Certificates のドキュメント](https://learn.microsoft.com/ja-jp/azure/app-service/configure-ssl-certificate)
- [Application Gateway の TLS 終端](https://learn.microsoft.com/ja-jp/azure/application-gateway/ssl-overview)
- [Key Vault での証明書管理](https://learn.microsoft.com/ja-jp/azure/key-vault/certificates/about-certificates)
- [OpenSSL コマンドリファレンス](https://www.openssl.org/docs/man1.1.1/man1/)

---

## ❓ よくある質問

**Q1: 証明書は必ず必要ですか？**

A1: いいえ。Front Door の既定ドメイン（`*.azurefd.net`）のみで運用する場合、証明書は不要です。この場合、Front Door が HTTPS 終端し、AppGW には HTTP で転送されます。

**Q2: ワイルドカード証明書は使えますか？**

A2: はい。`*.example.com` のようなワイルドカード証明書を使用できます。複数のサブドメインで API を公開する場合に便利です。

**Q3: 証明書の更新時にダウンタイムは発生しますか？**

A3: App Service Certificate を使用し、Key Vault 統合している場合、ダウンタイムは発生しません。証明書は自動更新され、Application Gateway も自動的に新しい証明書を使用します。

**Q4: 複数の証明書を Application Gateway に設定できますか？**

A4: はい。Application Gateway は複数の証明書をサポートしており、ホスト名ごとに異なる証明書を使用できます（SNI）。

**Q5: Let's Encrypt の証明書を自動更新するには？**

A5: Azure Automation や Azure Functions を使用して、90日ごとに証明書を更新するスクリプトを実行できます。Certbot を使用して証明書を取得し、Key Vault にアップロードするフローを構築します。

---

## 📝 次のステップ

証明書の準備ができたら、[ENTERPRISE_DEPLOYMENT.md](ENTERPRISE_DEPLOYMENT.md) に従ってデプロイを進めてください。
