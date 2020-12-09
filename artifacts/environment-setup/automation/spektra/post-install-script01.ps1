Param (
  [Parameter(Mandatory = $true)]
  [string]
  $azureUsername,

  [string]
  $azurePassword,

  [string]
  $azureTenantID,

  [string]
  $azureSubscriptionID,

  [string]
  $odlId,
    
  [string]
  $deploymentId
)

Start-Transcript -Path C:\WindowsAzure\Logs\CloudLabsCustomScriptExtension.txt -Append

[Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls
[Net.ServicePointManager]::SecurityProtocol = "tls12, tls11, tls" 

mkdir c:\labfiles -ea silentlycontinue;

#download the solliance pacakage
$WebClient = New-Object System.Net.WebClient;
$WebClient.DownloadFile("https://raw.githubusercontent.com/solliancenet/common-workshop/main/scripts/common.ps1","C:\LabFiles\common.ps1")

#run the solliance package
. C:\LabFiles\Common.ps1

Set-Executionpolicy unrestricted -force

CreateLabFilesDirectory

mkdir c:\temp -ea silentlycontinue
cd c:\temp

cd "c:\labfiles";

DisableInternetExplorerESC

EnableIEFileDownload

InstallAzPowerShellModule

InstallAzCli

InstallNotepadPP

InstallPutty

InstallChrome

InstallGit

$env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine")

InitSetup

cd "c:\labfiles";

CreateCredFile $azureUsername $azurePassword $azureTenantID $azureSubscriptionID $deploymentId $odlId

. C:\LabFiles\AzureCreds.ps1

Uninstall-AzureRm

$userName = $AzureUserName                # READ FROM FILE
$password = $AzurePassword                # READ FROM FILE
$clientId = $TokenGeneratorClientId       # READ FROM FILE
$global:sqlPassword = $AzureSQLPassword          # READ FROM FILE
$global:localusername = "wsuser";

$securePassword = $password | ConvertTo-SecureString -AsPlainText -Force
$cred = new-object -typename System.Management.Automation.PSCredential -argumentlist $userName, $SecurePassword

Connect-AzAccount -Credential $cred | Out-Null
 
#install sql server cmdlets
powershell.exe -c "`$user='$username'; `$pass='$password'; try { Invoke-Command -ScriptBlock { Install-Module -Name SqlServer -force } -ComputerName localhost -Credential (New-Object System.Management.Automation.PSCredential `$user,(ConvertTo-SecureString `$pass -AsPlainText -Force)) } catch { echo `$_.Exception.Message }" 

git clone https://github.com/solliancenet/security-workshop.git

# Template deployment
$rg = Get-AzResourceGroup | Where-Object { $_.ResourceGroupName -like "*-wssecurity" };
$resourceGroupName = $rg.ResourceGroupName
$deploymentId =  (Get-AzResourceGroup -Name $resourceGroupName).Tags["DeploymentId"]

$parametersFile = "c:\labfiles\security-workshop\artifacts\environment-setup\automation\spektra\deploy.parameters.post.json"
$content = Get-Content -Path $parametersFile -raw;

$content = $content.Replace("GET-AZUSER-PASSWORD",$azurepassword);
$content = $content | ForEach-Object {$_ -Replace "GET-AZUSER-UPN", "$AzureUsername"};
$content = $content | ForEach-Object {$_ -Replace "GET-ODL-ID", "$deploymentId"};
$content = $content | ForEach-Object {$_ -Replace "GET-DEPLOYMENT-ID", "$deploymentId"};
$content = $content | ForEach-Object {$_ -Replace "GET-REGION", "$($rg.location)"};
$content | Set-Content -Path "$($parametersFile).json";

New-AzResourceGroupDeployment -ResourceGroupName $resourceGroupName `
  -TemplateUri "https://raw.githubusercontent.com/solliancenet/security-workshop/master/artifacts/environment-setup/automation/00-core.json" `
  -TemplateParameterFile "$($parametersFile).json"

#set the keyvault
$keyVaultName = "wssecurity$deploymentId-kv";
Set-AzKeyVaultAccessPolicy -ResourceGroupName $resourceGroupName -VaultName $keyVaultName -UserPrincipalName $userName -PermissionsToSecrets get,list,set,delete,backup,restore,recover,purge -PermissionsToKeys decrypt,encrypt,unwrapKey,wrapKey,verify,sign,get,list,update,create,import,delete,backup,restore,recover,purge -PermissionsToCertificates get,list,delete,create,import,update,managecontacts,getissuers,listissuers,setissuers,deleteissuers,manageissuers,recover,purge,backup,restore

Publish-AzWebapp -ResourceGroupName $resourceGroupName -Name "wssecurity$deploymentId" -ArchivePath "c:\labfiles\security-workshop\artifacts\AzureKeyVaultMSI.zip" -force

sleep 20

Stop-Transcript