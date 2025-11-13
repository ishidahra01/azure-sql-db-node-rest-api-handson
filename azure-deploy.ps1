# Azure Function App Deployment Script for PowerShell
# PowerShell equivalent of azure-deploy.sh

# Exit on error
$ErrorActionPreference = "Stop"

Write-Host "=== Azure Function App Deployment Script ===" -ForegroundColor Cyan
Write-Host ""
Write-Host "To avoid resource name conflicts with other participants,"
Write-Host "please provide a unique identifier (e.g., your initials or username)."
Write-Host "This will be used as a suffix for all resource names."
Write-Host ""

# Prompt user for unique identifier
$userIdentifier = Read-Host "Enter your unique identifier (lowercase letters and numbers only)"

# Validate user input
if ($userIdentifier -notmatch "^[a-z0-9]+$") {
    Write-Host "Error: Identifier must contain only lowercase letters and numbers." -ForegroundColor Red
    exit 1
}

# Generate unique resource names using the user identifier
$resourceGroup = "rg-hands-on-${userIdentifier}"
$appName = "func-handson-${userIdentifier}"
$storageName = "sthandson${userIdentifier}"
$location = "eastus"

# Validate storage account name (must be 3-24 characters, lowercase letters and numbers only)
if ($storageName.Length -gt 24) {
    Write-Host "Error: Storage account name is too long. Please use a shorter identifier." -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "The following resources will be created:"
Write-Host "  Resource Group: $resourceGroup"
Write-Host "  Function App: $appName"
Write-Host "  Storage Account: $storageName"
Write-Host "  Location: $location"
Write-Host ""
$confirm = Read-Host "Continue with deployment? (yes/no)"
if ($confirm -ne "yes") {
    Write-Host "Deployment cancelled."
    exit 0
}

# Check that local.settings.json exists
$settingsFile = "./local.settings.json"
if (!(Test-Path $settingsFile)) {
    Write-Host "$settingsFile does not exist. Please create it." -ForegroundColor Red
    exit 1
}

Write-Host "Creating Resource Group..." -ForegroundColor Green
az group create `
    -n $resourceGroup `
    -l $location

Write-Host "Creating Application Insight..." -ForegroundColor Green
az resource create `
    -g $resourceGroup `
    -n "$appName-ai" `
    --resource-type "Microsoft.Insights/components" `
    --properties '{"Application_Type":"web"}'

Write-Host "Reading Application Insight Key..." -ForegroundColor Green
$aikey = az resource show -g $resourceGroup -n "$appName-ai" --resource-type "Microsoft.Insights/components" --query properties.InstrumentationKey -o tsv

Write-Host "Creating Storage Account..." -ForegroundColor Green
az storage account create `
    -g $resourceGroup `
    -l $location `
    -n $storageName `
    --sku Standard_LRS `
    --tags SecurityControl=Ignore

Write-Host "Creating Function App..." -ForegroundColor Green
az functionapp create `
    -g $resourceGroup `
    -n $appName `
    --storage-account $storageName `
    --app-insights-key $aikey `
    --consumption-plan-location $location `
    --functions-version 4 `
    --os-type Linux `
    --runtime node `
    --runtime-version 22

$CONN = az storage account show-connection-string -g $resourceGroup -n $storageName -o tsv
$AI_CONN = az resource show -g $resourceGroup -n "$appName-ai" `
    --resource-type "Microsoft.Insights/components" `
    --query properties.ConnectionString -o tsv

Write-Host "Configuring function..." -ForegroundColor Green

az functionapp config appsettings set -g $resourceGroup -n $appName --settings `
    AzureWebJobsStorage="$CONN" `
    FUNCTIONS_WORKER_RUNTIME="node" `
    FUNCTIONS_EXTENSION_VERSION="~4" `
    WEBSITE_RUN_FROM_PACKAGE="1" `
    APPLICATIONINSIGHTS_CONNECTION_STRING="$AI_CONN"

Write-Host "Configuring Connection String..." -ForegroundColor Green
$settings = @("db_server", "db_database", "db_user", "db_password")

# Read JSON file
$jsonContent = Get-Content $settingsFile -Raw | ConvertFrom-Json

foreach ($setting in $settings) {
    $value = $jsonContent.Values.$setting
    if ($null -ne $value) {
        Write-Host "Setting $setting..." -ForegroundColor Yellow
        az functionapp config appsettings set -g $resourceGroup -n $appName --settings "$setting=$value"
    }
}

Write-Host ""
Write-Host "Deploying local code to Function App..." -ForegroundColor Green
Write-Host "Building and packaging the application..." -ForegroundColor Green
npm install --production

Write-Host "Deploying to Azure..." -ForegroundColor Green
func azure functionapp publish $appName --javascript

Write-Host ""
Write-Host "========================================" -ForegroundColor Green
Write-Host "Deployment completed successfully!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host "Function App Name: $appName"
Write-Host "Resource Group: $resourceGroup"
Write-Host ""
Write-Host "You can test your API at:"
Write-Host "https://${appName}.azurewebsites.net/api/customer"
Write-Host ""
Write-Host "To view logs, run:"
Write-Host "  func azure functionapp logstream $appName"
Write-Host ""
Write-Host "Done." -ForegroundColor Green
