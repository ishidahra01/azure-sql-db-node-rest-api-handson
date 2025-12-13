# 🔄 ネットワークアーキテクチャ更新の概要

このドキュメントでは、エンタープライズ構成のネットワークアーキテクチャ更新の内容と設計判断を説明します。

## 📊 変更の概要

### 更新前（旧構成）

```
[Internet]
    ↓ HTTPS
[Azure Front Door Premium]
    ↓ HTTP (Public IP 経由)
[Application Gateway (Public IP のみ)]
    ↓ HTTP
[Azure Firewall] → [APIM] → [Functions] → [SQL]
```

### 更新後（新構成）

```
[Internet]
    ↓ HTTPS (Azure Front Door 既定ドメイン)
[Azure Front Door Premium]
    ↓ HTTP (Private Link トンネル経由)
[Application Gateway (Private + Public IP)]
    - Private IP: 実際の着地点
    - Public IP: 仕様上の存在要件（基本未使用）
    - TLS 終端 (証明書管理)
    ↓ HTTP (VNet内部)
[Azure Firewall] → [APIM] → [Functions] → [SQL]
```

---

## 🎯 主要な変更点

### 1. Front Door → AppGW を Private Link 接続に変更

**変更内容**:
- Front Door から Application Gateway への接続を Public IP から Private Link に変更
- Azure バックボーンネットワーク経由の閉域接続を実現

**技術的要件**:
- Front Door Premium SKU が必須（Private Link Origin をサポート）
- Application Gateway で Private Link 構成を作成
- Front Door からの接続要求を手動で承認する必要がある

**セキュリティ上のメリット**:
- インターネット露出の最小化
- Front Door のみが公開エンドポイント
- AppGW への直接アクセスを遮断

### 2. Application Gateway に Private + Public フロントエンド IP を追加

**変更内容**:
- Private フロントエンド IP: Front Door からの実際の着地点
- Public フロントエンド IP: Private Link 機能のための仕様上の要件

**重要な設計判断**:
> Application Gateway で Private Link をサポートするには、Public + Private 両方のフロントエンド IP が必要です。これは Azure の仕様です。

- Private IP のみの構成では Private Link をサポートしない
- Public IP は「使うため」ではなく「仕様上の存在要件」
- 実運用では Private IP のみを使用し、Public IP は未使用に寄せる

### 3. TLS 終端を Application Gateway で実装

**変更内容**:
- Application Gateway で TLS 終端を行う設計を追加
- 証明書管理を AppGW に集約
- AppGW 以降は HTTP で通信（VNet内部）

**証明書の扱い**:
- **Front Door**: Azure Front Door 既定ドメイン（`*.azurefd.net`）を使用 → 証明書管理不要
- **Application Gateway**: TLS 終端のため証明書必須（オプションパラメータ化）
  - App Service Certificate（推奨）
  - Let's Encrypt（無料）
  - 自己署名証明書（開発環境のみ）
  - 証明書なし（HTTP のみ、開発環境）

**設計理由**:
1. 証明書管理の一元化（AppGW のみで管理）
2. 内部通信を HTTP で簡素化（証明書運用の複雑さを回避）
3. VNet 内部は Azure のネットワーク分離により保護

### 4. 通信プロトコルの明確化

**更新された通信フロー**:
```
Internet → Front Door: HTTPS (既定ドメイン)
Front Door → AppGW: HTTP (Private Link トンネル)
AppGW → Firewall: HTTP (VNet内部)
Firewall → APIM: HTTP (VNet内部)
APIM → Functions: HTTPS (Private Endpoint)
Functions → SQL: TDS + TLS (必須、Private Endpoint)
```

**設計根拠**:
- Internet → Front Door: HTTPS 必須（公開エンドポイント）
- Front Door → AppGW: HTTP（Private Link トンネル内、Azure バックボーン経由）
- VNet内部: HTTP（証明書運用の簡素化、Azure VNet の分離で保護）
- PaaS境界: TDS + TLS 必須（Functions → SQL は暗号化必須）

---

## 🔧 実装の詳細

### modules/appgw.bicep の変更

1. **Private Link 構成の追加**:
```bicep
privateLinkConfigurations: [
  {
    name: privateLinkConfigName
    properties: {
      ipConfigurations: [
        {
          name: 'privateLinkIpConfig'
          properties: {
            privateIPAllocationMethod: 'Dynamic'
            subnet: {
              id: appGwSubnetId
            }
          }
        }
      ]
    }
  }
]
```

2. **フロントエンド IP 構成の拡張**:
```bicep
frontendIPConfigurations: [
  {
    name: 'appGwPublicFrontendIp'  // 仕様上の存在要件
    properties: {
      publicIPAddress: {
        id: publicIp.id
      }
    }
  }
  {
    name: 'appGwPrivateFrontendIp'  // 実際の着地点
    properties: {
      privateIPAllocationMethod: 'Dynamic'
      subnet: {
        id: appGwSubnetId
      }
    }
  }
]
```

3. **証明書サポートの追加**:
```bicep
sslCertificates: hasCertificate ? [
  {
    name: 'appgw-ssl-cert'
    properties: {
      data: tlsCertificateData
      password: tlsCertificatePassword
    }
  }
] : []
```

### modules/frontdoor.bicep の変更

1. **Private Link Origin の設定**:
```bicep
resource frontDoorOrigin 'Microsoft.Cdn/profiles/originGroups/origins@2023-05-01' = {
  properties: {
    hostName: appGwPrivateIp
    // Private Link 設定
    sharedPrivateLinkResource: {
      privateLink: {
        id: appGwResourceId
      }
      privateLinkLocation: resourceGroup().location
      groupId: appGwPrivateLinkConfigId
      requestMessage: 'Front Door Private Link request'
    }
  }
}
```

2. **HTTPS リダイレクトの有効化**:
```bicep
resource frontDoorRoute 'Microsoft.Cdn/profiles/afdEndpoints/routes@2023-05-01' = {
  properties: {
    forwardingProtocol: 'HttpOnly'
    httpsRedirect: 'Enabled'  // インターネットからは HTTPS を強制
  }
}
```

### main-enterprise.bicep の変更

1. **証明書パラメータの追加**:
```bicep
@description('Application Gateway の TLS 証明書データ (Base64エンコード) - オプション')
@secure()
param tlsCertificateData string = ''

@description('Application Gateway の TLS 証明書パスワード - オプション')
@secure()
param tlsCertificatePassword string = ''
```

2. **モジュールパラメータの更新**:
```bicep
module appGw 'modules/appgw.bicep' = {
  params: {
    // ...
    tlsCertificateData: tlsCertificateData
    tlsCertificatePassword: tlsCertificatePassword
  }
}

module frontDoor 'modules/frontdoor.bicep' = {
  params: {
    appGwResourceId: appGw.outputs.appGwId
    appGwPrivateLinkConfigId: appGw.outputs.privateLinkConfigurationId
    appGwPrivateIp: appGw.outputs.appGwPrivateIp
  }
}
```

---

## 📋 デプロイ後の追加手順

### 1. Private Link 接続の承認

デプロイ後、Front Door からの Private Link 接続要求を承認する必要があります。

**Azure Portal での承認**:
1. Application Gateway のリソースを開く
2. Settings → Private Link を選択
3. Private endpoint connections タブを開く
4. Front Door からの接続要求（Status: Pending）を選択
5. Approve をクリック

**Azure CLI での承認**:
```bash
az network application-gateway private-link approve \
  --resource-group rg-handson-prod \
  --gateway-name appgw-handson-prod \
  --name <private-endpoint-connection-name>
```

### 2. 証明書のセットアップ（オプション）

証明書を使用する場合は、[CERTIFICATE_GUIDE.md](CERTIFICATE_GUIDE.md) を参照してください。

---

## 🔍 トラブルシューティング

### Front Door から AppGW に接続できない

**症状**: Front Door のヘルスチェックが失敗、API リクエストがタイムアウト

**原因と対処**:
1. Private Link 接続が承認されていない
   - Azure Portal で AppGW → Private Link を確認
   - 接続要求を承認

2. Front Door のプロビジョニングが未完了
   - Front Door のデプロイには 30-60 分かかる
   - Azure Portal で Front Door のステータスを確認

3. Application Gateway のヘルスチェック設定
   - バックエンドプールのヘルスステータスを確認
   - Firewall への接続が正常か確認

### 証明書エラー

**症状**: HTTPS リスナーが動作しない、証明書エラー

**原因と対処**:
1. 証明書データが正しくエンコードされていない
   - Base64 エンコードを確認
   - 改行コードが含まれていないか確認

2. 証明書パスワードが間違っている
   - パラメータファイルのパスワードを確認

3. 証明書の形式が間違っている
   - PFX 形式（PKCS#12）を使用
   - CER や PEM 形式は直接使用不可

### Public IP が削除できない

**症状**: Application Gateway の Public IP を削除したい

**注意**: 
- Private Link 機能を使用する場合、Public IP の削除は不可
- Public IP は仕様上の存在要件
- 実運用では未使用に寄せるが、リソース自体は必要

---

## 📚 関連ドキュメント

- [ARCHITECTURE.md](ARCHITECTURE.md) - アーキテクチャ全体の詳細
- [ENTERPRISE_DEPLOYMENT.md](ENTERPRISE_DEPLOYMENT.md) - デプロイ手順
- [CERTIFICATE_GUIDE.md](CERTIFICATE_GUIDE.md) - 証明書管理ガイド
- [modules/appgw.bicep](modules/appgw.bicep) - Application Gateway モジュール
- [modules/frontdoor.bicep](modules/frontdoor.bicep) - Front Door モジュール

---

## ✅ 検証項目

デプロイ後、以下を確認してください:

- [ ] Front Door のエンドポイントが正常に作成されている
- [ ] Application Gateway の Private Link 接続が承認されている
- [ ] Application Gateway のヘルスチェックが正常（Backend Health）
- [ ] Front Door 経由で API にアクセスできる
- [ ] HTTPS リダイレクトが動作している（HTTP → HTTPS）
- [ ] 証明書が正しく設定されている（使用する場合）
- [ ] VNet 内部の通信が HTTP で動作している
- [ ] Functions → SQL の接続が TLS で暗号化されている

---

## 🎯 設計の意図

この更新により、以下の目標を達成しています:

1. **セキュリティの強化**
   - インターネット露出の最小化
   - Private Link による閉域接続
   - 多層防御アーキテクチャの実現

2. **証明書管理の簡素化**
   - TLS 終端を Application Gateway に集約
   - 内部通信は HTTP で簡素化
   - Front Door は既定ドメインで証明書管理不要

3. **Azure のベストプラクティスに準拠**
   - Private Link の適切な使用
   - VNet 統合とネットワーク分離
   - PaaS 境界での暗号化強制

4. **運用性の向上**
   - 証明書の自動更新（App Service Certificate 使用時）
   - インフラのコード化（Bicep）
   - 段階的なデプロイが可能

---

このアーキテクチャ更新により、エンタープライズレベルのセキュアなネットワーク構成が実現されました。
