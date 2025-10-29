#!/bin/bash

set -euo pipefail

# Make sure these values are correct for your environment
resourceGroup="rg-hands-on"
appName="func-hands-on-app"
storageName="sthandsonstorage"
location="japaneast"

# Change this if you are using your own github repository
gitSource="https://github.com/ishidahra01/azure-sql-db-node-rest-api-handson.git"

# Check that local.settings.json exists
settingsFile="./local.settings.json"
if ! [ -f $settingsFile ]; then
    echo "$settingsFile does not exists. Please create it."
    exit
fi

echo "Creating Resource Group...";
az group create \
    -n $resourceGroup \
    -l $location

echo "Creating Application Insight..."
az resource create \
    -g $resourceGroup \
    -n $appName-ai \
    --resource-type "Microsoft.Insights/components" \
    --properties '{"Application_Type":"web"}'

echo "Reading Application Insight Key..."
aikey=`az resource show -g $resourceGroup -n $appName-ai --resource-type "Microsoft.Insights/components" --query properties.InstrumentationKey -o tsv`

echo "Creating Storage Account...";
az storage account create \
    -g $resourceGroup \
    -l $location \
    -n $storageName \
    --sku Standard_LRS

echo "Creating Function App...";
az functionapp create \
    -g $resourceGroup \
    -n $appName \
    --storage-account $storageName \
    --app-insights-key $aikey \
    --consumption-plan-location $location \
    --deployment-source-url $gitSource \
    --deployment-source-branch main \
    --functions-version 4 \
    --os-type Linux \
    --runtime node \
    --runtime-version 18 \

echo "Configuring Connection String...";
settings=(db_server db_database db_user db_password)
for i in "${settings[@]}"
do
    v=`cat local.settings.json | jq .Values.$i -r`
    c="az functionapp config appsettings set -g $resourceGroup -n $appName --settings $i='$v'"
    #echo $c
	eval $c
done

echo "Done."