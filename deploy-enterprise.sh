#!/bin/bash

# エンタープライズ構成デプロイスクリプト
# このスクリプトは、本格的なセキュア構成をAzureにデプロイします

set -e

echo "========================================="
echo "  Azure エンタープライズ構成デプロイ"
echo "========================================="
echo ""

# カラー設定
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# パラメータファイルの確認
PARAM_FILE="main-enterprise.parameters.json"
TEMPLATE_FILE="main-enterprise.bicep"

if [ ! -f "$PARAM_FILE" ]; then
    echo -e "${YELLOW}警告: パラメータファイルが見つかりません。${NC}"
    echo "テンプレートからコピーします..."
    cp main-enterprise.parameters.json.template "$PARAM_FILE"
    echo ""
    echo -e "${RED}重要: $PARAM_FILE を編集して、以下の値を設定してください:${NC}"
    echo "  - sqlAdminPassword: 強力なパスワード"
    echo "  - apimPublisherEmail: 実際のメールアドレス"
    echo "  - apimPublisherName: 組織名"
    echo ""
    read -p "編集が完了したらEnterキーを押してください..." 
fi

# Azure ログイン確認
echo "Azure ログイン状態を確認中..."
if ! az account show &> /dev/null; then
    echo -e "${YELLOW}Azure にログインしていません。ログインを開始します...${NC}"
    az login
else
    echo -e "${GREEN}✅ Azure にログイン済み${NC}"
    SUBSCRIPTION=$(az account show --query name -o tsv)
    echo "サブスクリプション: $SUBSCRIPTION"
    echo ""
    read -p "このサブスクリプションでよろしいですか？ (yes/no): " confirm
    if [ "$confirm" != "yes" ]; then
        echo "デプロイを中止しました。"
        echo "別のサブスクリプションを使用する場合は、以下のコマンドを実行してください:"
        echo "  az account set --subscription 'YOUR_SUBSCRIPTION_ID'"
        exit 0
    fi
fi

echo ""

# リソースグループ名の入力
read -p "リソースグループ名を入力してください (例: rg-handson-prod): " RESOURCE_GROUP

if [ -z "$RESOURCE_GROUP" ]; then
    echo -e "${RED}エラー: リソースグループ名が入力されませんでした。${NC}"
    exit 1
fi

# リージョンの入力
read -p "デプロイ先のリージョンを入力してください (デフォルト: japaneast): " LOCATION
LOCATION=${LOCATION:-japaneast}

echo ""
echo "========================================="
echo "  デプロイ設定確認"
echo "========================================="
echo "リソースグループ: $RESOURCE_GROUP"
echo "リージョン: $LOCATION"
echo "テンプレート: $TEMPLATE_FILE"
echo "パラメータ: $PARAM_FILE"
echo ""
echo -e "${YELLOW}推定デプロイ時間: 60-90分${NC}"
echo -e "${YELLOW}推定月額コスト: $4,000-5,000${NC}"
echo ""
read -p "デプロイを開始しますか？ (yes/no): " start_deploy

if [ "$start_deploy" != "yes" ]; then
    echo "デプロイを中止しました。"
    exit 0
fi

echo ""

# リソースグループの作成
echo "========================================="
echo "  Step 1: リソースグループの作成"
echo "========================================="

if az group show --name "$RESOURCE_GROUP" &> /dev/null; then
    echo -e "${GREEN}✅ リソースグループ '$RESOURCE_GROUP' は既に存在します${NC}"
else
    echo "リソースグループを作成中..."
    az group create --name "$RESOURCE_GROUP" --location "$LOCATION"
    echo -e "${GREEN}✅ リソースグループを作成しました${NC}"
fi

echo ""

# Bicep テンプレートの検証
echo "========================================="
echo "  Step 2: テンプレートの検証"
echo "========================================="

echo "Bicep 構文をチェック中..."
if az bicep build --file "$TEMPLATE_FILE" > /dev/null 2>&1; then
    echo -e "${GREEN}✅ Bicep 構文チェック成功${NC}"
else
    echo -e "${RED}❌ Bicep 構文エラーが見つかりました${NC}"
    az bicep build --file "$TEMPLATE_FILE"
    exit 1
fi

echo ""
echo "What-If 分析を実行中（デプロイせずに変更を確認）..."
echo "※ この処理には数分かかる場合があります"
echo ""

az deployment group what-if \
    --resource-group "$RESOURCE_GROUP" \
    --template-file "$TEMPLATE_FILE" \
    --parameters "$PARAM_FILE" \
    --no-pretty-print

echo ""
read -p "上記の変更内容でよろしいですか？ (yes/no): " confirm_whatif

if [ "$confirm_whatif" != "yes" ]; then
    echo "デプロイを中止しました。"
    exit 0
fi

echo ""

# デプロイの実行
echo "========================================="
echo "  Step 3: デプロイの実行"
echo "========================================="

DEPLOYMENT_NAME="enterprise-$(date +%Y%m%d-%H%M%S)"

echo "デプロイを開始します..."
echo "デプロイ名: $DEPLOYMENT_NAME"
echo ""
echo -e "${YELLOW}⏳ デプロイには 60-90 分かかります。気長にお待ちください...${NC}"
echo ""

START_TIME=$(date +%s)

az deployment group create \
    --resource-group "$RESOURCE_GROUP" \
    --template-file "$TEMPLATE_FILE" \
    --parameters "$PARAM_FILE" \
    --name "$DEPLOYMENT_NAME" \
    --verbose

DEPLOY_RESULT=$?
END_TIME=$(date +%s)
ELAPSED=$((END_TIME - START_TIME))
ELAPSED_MIN=$((ELAPSED / 60))

echo ""

if [ $DEPLOY_RESULT -eq 0 ]; then
    echo "========================================="
    echo -e "${GREEN}  ✅ デプロイ成功！${NC}"
    echo "========================================="
    echo "所要時間: ${ELAPSED_MIN} 分"
    echo ""
    
    # デプロイ結果の出力
    echo "デプロイされたリソース:"
    echo ""
    az deployment group show \
        --resource-group "$RESOURCE_GROUP" \
        --name "$DEPLOYMENT_NAME" \
        --query "properties.outputs" \
        --output json
    
    echo ""
    echo "========================================="
    echo "  次のステップ"
    echo "========================================="
    echo ""
    echo "1. SQL スクリプトの実行:"
    echo "   - Azure Portal で SQL Database を開く"
    echo "   - Query Editor で sql/HandsOnSetup.sql を実行"
    echo ""
    echo "2. Functions コードのデプロイ:"
    echo "   func azure functionapp publish <functionAppName>"
    echo ""
    echo "3. 動作確認:"
    echo "   詳細は ENTERPRISE_DEPLOYMENT.md を参照してください"
    echo ""
else
    echo "========================================="
    echo -e "${RED}  ❌ デプロイ失敗${NC}"
    echo "========================================="
    echo ""
    echo "エラーログを確認してください:"
    echo "  az deployment group show --resource-group $RESOURCE_GROUP --name $DEPLOYMENT_NAME"
    echo ""
    exit 1
fi
