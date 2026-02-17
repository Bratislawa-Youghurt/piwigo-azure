param (
    [string]$RegistryName = "bycontreg",
    [string]$ImageName = "piwigo-custom",
    [string]$Tag = "v1"
)

$ConfirmPreference = 'None'
$ErrorActionPreference = 'Stop'

try {
    Write-Host "Starting Azure ACR Build..." -ForegroundColor Cyan
    Write-Host "Registry: $RegistryName"
    Write-Host "Image:    $($ImageName):$($Tag)"
    
    # Run the build command
    # using --registry simply takes the name, not the full URL usually, but let's be safe and use just the name if passsed 'bycontreg'
    # If the user passed full bycontreg.azurecr.io, az acr build handles it or errors out, usually it prefers the resource name 'bycontreg'.
    
    $cleanRegistryName = $RegistryName -replace "\.azurecr\.io$", ""
    
    az acr build --registry $cleanRegistryName --image "$($ImageName):$($Tag)" .

    if ($LASTEXITCODE -eq 0) {
        Write-Host "`n----------------------------------------------------------------"
        Write-Host "Build and Push Successful!" -ForegroundColor Green
        Write-Host "Image pushed to: $cleanRegistryName.azurecr.io/$($ImageName):$($Tag)"
        Write-Host "----------------------------------------------------------------"
        Write-Host "To update your App Service, run this command:" -ForegroundColor Yellow
        Write-Host "az webapp config container set --name bypiwigo --resource-group BY-webhosting --docker-custom-image-name $cleanRegistryName.azurecr.io/$($ImageName):$($Tag) --docker-registry-server-url https://$cleanRegistryName.azurecr.io"
    }
}
catch {
    Write-Host "An error occurred during the build process." -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Red
}
