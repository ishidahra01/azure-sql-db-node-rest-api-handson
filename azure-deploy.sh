#!/bin/bash

set -euo pipefail

# Prompt user for unique identifier to avoid resource name conflicts
echo "=== Azure Function App Deployment Script ==="
echo ""
echo "To avoid resource name conflicts with other participants,"
echo "please provide a unique identifier (e.g., your initials or username)."
echo "This will be used as a suffix for all resource names."
echo ""
read -p "Enter your unique identifier (lowercase letters and numbers only): " userIdentifier

# Validate user input
if [[ ! $userIdentifier =~ ^[a-z0-9]+$ ]]; then
    echo "Error: Identifier must contain only lowercase letters and numbers."
    exit 1
fi

# Generate unique resource names using the user identifier
resourceGroup="rg-hands-on-${userIdentifier}"
appName="func-handson-${userIdentifier}"
storageName="sthandson${userIdentifier}"
location="eastus"

# Validate storage account name (must be 3-24 characters, lowercase letters and numbers only)
if [ ${#storageName} -gt 24 ]; then
    echo "Error: Storage account name is too long. Please use a shorter identifier."
    exit 1
fi

echo ""
echo "The following resources will be created:"
echo "  Resource Group: $resourceGroup"
echo "  Function App: $appName"
echo "  Storage Account: $storageName"
echo "  Location: $location"
echo ""
read -p "Continue with deployment? (yes/no): " confirm
if [ "$confirm" != "yes" ]; then
    echo "Deployment cancelled."
    exit 0
fi

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
    --sku Standard_LRS \
    --tags SecurityControl=Ignore

echo "Creating Function App...";
az functionapp create \
    -g $resourceGroup \
    -n $appName \
    --storage-account $storageName \
    --app-insights-key $aikey \
    --consumption-plan-location $location \
    --functions-version 4 \
    --os-type Linux \
    --runtime node \
    --runtime-version 24

echo "Configuring Connection String...";
settings=(db_server db_database db_user db_password)
for i in "${settings[@]}"
do
    v=`cat local.settings.json | jq .Values.$i -r`
    c="az functionapp config appsettings set -g $resourceGroup -n $appName --settings $i='$v'"
    #echo $c
	eval $c
done

echo ""
echo "Deploying local code to Function App..."
echo "Building and packaging the application..."
npm install --production

echo "Deploying to Azure..."
func azure functionapp publish $appName --javascript

echo ""
echo "========================================"
echo "Deployment completed successfully!"
echo "========================================"
echo "Function App Name: $appName"
echo "Resource Group: $resourceGroup"
echo ""
echo "You can test your API at:"
echo "https://${appName}.azurewebsites.net/api/customer"
echo ""
echo "To view logs, run:"
echo "  func azure functionapp logstream $appName"
echo ""
echo "Done."