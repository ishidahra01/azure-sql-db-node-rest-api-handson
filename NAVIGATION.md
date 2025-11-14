# 📍 ナビゲーションガイド

> このドキュメントは、ハンズオン教材のナビゲーション用クイックリファレンスです。

## 🎯 自分に合った学習パスを選ぶ

### 時間がない、とにかく動かしたい
→ **[🚀 パス1: クイックスタート](QUICKSTART.md)** （30分）

### 基本からしっかり学びたい
→ **[📘 パス2: 標準ハンズオン](README.md)** （2-3時間）

### 本番レベルの構成を構築したい
→ **[🏗️ パス3: 本番構成への拡張](BICEP_README.md)** （半日～）

---

## 📚 ドキュメントマップ

```
ハンズオン教材
│
├─ 🚀 パス1: クイックスタート
│   └─ QUICKSTART.md ←【ここから開始】
│       ├─ LOCAL_SETUP.md（必要に応じて）
│       ├─ sql/README.md（SQLスクリプト）
│       └─ sample-usage.md（APIテスト）
│
├─ 📘 パス2: 標準ハンズオン
│   └─ README.md ←【ここから開始】
│       ├─ LOCAL_SETUP.md（開発環境準備）
│       ├─ sql/README.md（SQLスクリプト）
│       ├─ sample-usage.md（APIテスト）
│       └─ azure-deploy.sh / azure-deploy.ps1（簡易デプロイ、Bash/PowerShell）
│
└─ 🏗️ パス3: 本番構成への拡張
    └─ BICEP_README.md ←【ここから開始】
        ├─ main.bicep（IaCテンプレート）
        ├─ deploy-function-code.sh / deploy-function-code.ps1（コードデプロイ、Bash/PowerShell）
        ├─ ハンズオンTips.md（設計論点）
        └─ README.md Section 4（冗長化・閉域化）
```

---

## 📄 各ドキュメントの役割

| ドキュメント | いつ読む？ | 何のため？ |
|------------|----------|----------|
| **[QUICKSTART.md](QUICKSTART.md)** | 最初 | 最短でAPIを動かす |
| **[README.md](README.md)** | 基本を学ぶ時 | ハンズオン全体の流れと詳細 |
| **[LOCAL_SETUP.md](LOCAL_SETUP.md)** | 開発環境準備時 | ツールのインストール手順 |
| **[BICEP_README.md](BICEP_README.md)** | 本番構成を試す時 | IaCで本番レベルをデプロイ |
| **[ハンズオンTips.md](ハンズオンTips.md)** | 発展学習時 | 実務の設計論点とTips |
| **[sample-usage.md](sample-usage.md)** | API実行時 | エンドポイントとテスト方法 |
| **[sql/README.md](sql/README.md)** | SQL準備時 | SQLスクリプトの説明 |

---

## 🛠️ よくあるシチュエーション別ガイド

### 「Azure Functions を初めて使う」
1. [QUICKSTART.md](QUICKSTART.md) でまず動かしてみる
2. 動いたら [README.md](README.md) で詳しく学ぶ

### 「Windows/プロキシ環境で開発する」
1. [LOCAL_SETUP.md](LOCAL_SETUP.md) で環境準備
2. その後、選んだパスに進む

### 「API のテスト方法を知りたい」
→ [sample-usage.md](sample-usage.md)

### 「エラーが出た」
1. [sample-usage.md](sample-usage.md) のトラブルシューティング
2. [QUICKSTART.md](QUICKSTART.md) のトラブルシューティング
3. [README.md Section 5](README.md#5-トラブルシューティング)

### 「本番構成の設計論点を深く知りたい」
→ [ハンズオンTips.md](ハンズオンTips.md)

### 「Azure にデプロイしたい」
- **簡易デプロイ**: [README.md Step 3](README.md#step-3-azure-へのデプロイオプション) + `azure-deploy.sh` / `azure-deploy.ps1`
- **本番構成**: [BICEP_README.md](BICEP_README.md) + `main.bicep`

---

## 🔗 外部リソース

- [Azure Functions 公式ドキュメント](https://learn.microsoft.com/ja-jp/azure/azure-functions/)
- [Azure SQL Database 公式ドキュメント](https://learn.microsoft.com/ja-jp/azure/azure-sql/database/)
- [Bicep 公式ドキュメント](https://learn.microsoft.com/ja-jp/azure/azure-resource-manager/bicep/)

---

**💡 Tip**: 迷ったら [README.md](README.md) の冒頭に戻って、3つの学習パスから選び直してください！
