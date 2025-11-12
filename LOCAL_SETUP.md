# 📘 ローカル開発環境のセットアップ手順

*(通常環境 & プロキシ環境対応 / Windows想定)*

本ドキュメントでは、Azure Functions のローカル開発に必要なツール類について、
**通常環境・プロキシ環境**の両方のセットアップ方法をまとめています。

---

# 🧱 必要なツール一覧

| ツール                               | 必須 | 備考                          |
| --------------------------------- | -- | --------------------------- |
| **Node.js v20+（npm同梱）**           | ✔  | Functions Core Tools で必要    |
| **Azure CLI**                     | ✔  | Azure操作全般                   |
| **Azure Functions Core Tools v4** | ✔  | Functions ローカル実行            |
| **Visual Studio Code**            | ✔  | 開発エディタ                      |
| **VSCode 拡張：Azure Functions**     | ✔  | 関数開発テンプレ                    |
| **Azurite**                       | △  | ローカルの Azure Storage エミュレーター |

---

# 🚀 1. Node.js (v20+) インストール

## 【通常環境】

1. 公式サイトから LTS 版の Windows Installer (MSI) をダウンロード
   [https://nodejs.org/en/download](https://nodejs.org/en/download)
2. インストール実行（npm も同時にインストールされます）
3. バージョン確認

   ```powershell
   node -v
   npm -v
   ```

## 【プロキシ環境】

1. 上記と同じく MSI をダウンロードして実行（プロキシ影響なし）
2. npm のプロキシ設定（必須）

   ```powershell
   npm config set proxy http://proxy.company.local:8080
   npm config set https-proxy http://proxy.company.local:8080
   npm config set strict-ssl false   # 社内CAなど自己署名証明書の場合
   ```
3. 設定確認

   ```powershell
   npm config list
   ```

---

# 🌐 2. Azure CLI インストール

## 【通常環境】

1. Windows用 MSI をダウンロード
   [https://aka.ms/installazurecliwindows](https://aka.ms/installazurecliwindows)
2. インストール実行
3. バージョン確認

   ```powershell
   az --version
   ```

## 【プロキシ環境】

Azure CLI はプロキシ環境に対応済み。

### OS の環境変数設定

```powershell
setx HTTP_PROXY  http://proxy.company.local:8080
setx HTTPS_PROXY http://proxy.company.local:8080
```

### 認証（ブラウザがプロキシでブロックされる場合）

```powershell
az login --use-device-code
```

---

# ⚙️ 3. Azure Functions Core Tools (v4)

## 【通常環境（推奨: MSI / ZIP）】

npm を使わなくてもインストール可能です。

### MSI or ZIP を入手

[https://github.com/Azure/azure-functions-core-tools/releases](https://github.com/Azure/azure-functions-core-tools/releases)

* Windows → `Azure.Functions.Cli.win-x64.*.zip` もしくは `.msi`

### ZIP版の例

1. ダウンロードして解凍
2. 任意の場所に配置（例：`C:\tools\func`）
3. PATH を追加

   ```powershell
   setx PATH "%PATH%;C:\tools\func"
   ```
4. 動作確認

   ```powershell
   func --version
   ```

## 【プロキシ環境】

* 上記「MSI / ZIP」方式が **最も確実で推奨**
* npm を使う場合は Node.js のプロキシ設定必須（前述）

---

# 🧰 4. Visual Studio Code（＋ Azure Functions Extension）

## 【通常環境】

1. VSCodeインストール
   [https://code.visualstudio.com/download](https://code.visualstudio.com/download)
2. 拡張機能から
   **"Azure Functions"** を検索してインストール

## 【プロキシ環境】

VSCode は独自のプロキシ設定が必要な場合があります。

### 設定 → `settings.json`

```json
{
  "http.proxy": "http://proxy.company.local:8080",
  "http.proxyStrictSSL": false
}
```

その後、拡張機能から「Azure Functions」をインストール。

---

# 📦 5. Azurite（Azure Storage Emulator）

## 【通常環境】

方法は 2つ：

### ① VSCode拡張（最も簡単）

1. VSCode → 拡張機能
2. **Azurite** を検索してインストール
3. コマンドパレット → `Azurite: Start`

### ② Docker

```powershell
docker run -p 10000:10000 -p 10001:10001 -p 10002:10002 mcr.microsoft.com/azure-storage/azurite
```

## 【プロキシ環境】

npmを使う場合はプロキシ設定が必要。（Node.jsの項参照）

スタンドアローンで使いたい場合：

### ① VSCode拡張 → プロキシ影響なし（VSCode経由でDLできればOK）

### ② Docker版 → 企業環境でも確実

Docker のプロキシ設定が必要な場合は次のファイルへ設定：

`C:\ProgramData\Docker\config\daemon.json`

```json
{
  "proxies": {
    "default": {
      "httpProxy":  "http://proxy.company.local:8080",
      "httpsProxy": "http://proxy.company.local:8080",
      "noProxy": "localhost"
    }
  }
}
```

---

# 🎉 6. 動作確認（全体）

Azure Functions プロジェクトを作成して動作確認します。

```powershell
func init MyFunctionProj --worker-runtime node
cd MyFunctionProj
func new --template "HTTP trigger" --name HttpFunction
func start
```

ブラウザで
👉 [http://localhost:7071/api/HttpFunction](http://localhost:7071/api/HttpFunction)
が動作すればOK。
