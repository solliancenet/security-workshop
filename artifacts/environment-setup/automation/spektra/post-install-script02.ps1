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

CreateLabFilesDirectory

mkdir c:\temp -ea SilentlyContinue
mkdir c:\logs -ea SilentlyContinue

$env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine")

cd "c:\labfiles";

DisableInternetExplorerESC

EnableIEFileDownload

InstallAzPowerShellModule

InstallAzCli

InstallChrome

InstallNotepadPP

InstallPutty

InstallGit

InstallChocolaty

InstallFiddler;

#do twice...just in case.
InstallFiddler;

Uninstall-AzureRm

CreateCredFile $azureUsername $azurePassword $azureTenantID $azureSubscriptionID $deploymentId $odlId

. C:\LabFiles\AzureCreds.ps1

$userName = $AzureUserName                # READ FROM FILE
$password = $AzurePassword                # READ FROM FILE
$clientId = $TokenGeneratorClientId       # READ FROM FILE
$global:sqlPassword = $AzureSQLPassword          # READ FROM FILE

$securePassword = $password | ConvertTo-SecureString -AsPlainText -Force
$cred = new-object -typename System.Management.Automation.PSCredential -argumentlist $userName, $SecurePassword

Connect-AzAccount -Credential $cred | Out-Null

git clone https://github.com/solliancenet/security-workshop.git

$rg = Get-AzResourceGroup | Where-Object { $_.ResourceGroupName -like "*-wssecurity" };
$resourceGroupName = $rg.ResourceGroupName
$deploymentId =  (Get-AzResourceGroup -Name $resourceGroupName).Tags["DeploymentId"]

#get the waf public IP
$wafName = "wssecurity" + $deploymentId + "-ag";
$appGW = Get-AzApplicationGateway -name $wafName;
$fipconfig = Get-AzApplicationGatewayFrontendIPConfig -ApplicationGateway $appGW
$pipName = "wssecurity" + $deploymentId + "-pip"
$ip = Get-AzPublicIpAddress -name $pipName
$wafIp = $ip.IpAddress;

#get the app svc url
$webAppName = "wssecurity" + $deploymentId;
$app = Get-AzWebApp -Name $webAppName
$appHost = $app.HostNames[0];
$appUrlFull = "https://" + $app.HostNames[0];

#get the workspace Id
$wsName = "wssecurity" + $deploymentId;
$ws = Get-AzOperationalInsightsWorkspace -Name $wsName -ResourceGroup $resourceGroupName;
$workspaceId = $ws.CustomerId;
$keys = Get-AzOperationalInsightsWorkspaceSharedKey -ResourceGroup $resourceGroupName -Name $wsName;
$workspaceKey = $keys.PrimarySharedKey;

#update the updatedatafiles.ps1
$content = get-content "c:\labfiles\security-workshop\artifacts\updatedatafiles.ps1" -raw
$content = $content.replace("#IN_WORKSPACE_NAME#",$wsName);
$content = $content.replace("#IN_WORKSPACE_ID#",$workspaceId);
$content = $content.replace("#IN_WORKSPACE_KEY#",$workspaceKey);
$content = $content.replace("#IN_SUBSCRIPTION_ID#",$azureSubscriptionID);
$content = $content.replace("#IN_RESOURCE_GROUP_NAME#",$resourceGroupName);
$content = $content.replace("#IN_DEPLOYMENT_ID#",$deploymentId);
$content = $content.replace("#IN_IP#","192.168.102.2");
$content = $content.replace("#IN_WAF_IP#",$wafIp);
$content = $content.replace("#IN_APP_SVC_URL#",$appHost);
set-content "c:\labfiles\security-workshop\artifacts\updatedatafiles.ps1" $content;

. "c:\labfiles\security-workshop\artifacts\updatedatafiles.ps1"

#install azcopy
$azCopyLink = Check-HttpRedirect "https://aka.ms/downloadazcopy-v10-windows"

if (!$azCopyLink)
{
        $azCopyLink = "https://azcopyvnext.azureedge.net/release20200501/azcopy_windows_amd64_10.4.3.zip"
}

Invoke-WebRequest $azCopyLink -OutFile "azCopy.zip"
Expand-Archive "azCopy.zip" -DestinationPath ".\" -Force
$azCopyCommand = (Get-ChildItem -Path ".\" -Recurse azcopy.exe).Directory.FullName
$azCopyCommand += "\azcopy"

#upload the updated login files to azure storage
$wsName = "wssecurity" + $deploymentId;
$dataLakeStorageBlobUrl = "https://"+ $wsName + ".blob.core.windows.net/"
$dataLakeStorageAccountKey = (Get-AzStorageAccountKey -ResourceGroupName $resourceGroupName -AccountName $wsName)[0].Value
$dataLakeContext = New-AzStorageContext -StorageAccountName $wsName -StorageAccountKey $dataLakeStorageAccountKey
$container = New-AzStorageContainer -Permission Container -name "logs" -context $dataLakeContext;
$destinationSasKey = New-AzStorageContainerSASToken -Container "logs" -Context $dataLakeContext -Permission rwdl

Write-Information "Copying single files from local..."

$singleFiles = @{
  queries = "c:\labfiles\security-workshop\artifacts\queries.yaml,logs/queries.yaml"
  aad_logons = "c:\labfiles\security-workshop\artifacts\aad_logons.pkl,logs/aad_logon.pkl"
  host_logins = "c:\labfiles\security-workshop\artifacts\host_logins.csv,logs/host_logins.csv"
}

foreach ($singleFile in $singleFiles.Keys) 
{
  $vals = $singleFiles[$singleFile].split(",");
  $vals;
  $source = $vals[0]
  $destination = $dataLakeStorageBlobUrl + $vals[1] + $destinationSasKey
  Write-Host "Copying file $($source) to $($destination)"
  Write-Information "Copying file $($source) to $($destination)"
  & $azCopyCommand copy $source $destination 
}

#add to HOSTS
$line = "#$wafIp`t$appHost"
add-content "c:\windows\system32\drivers\etc\HOSTS" $line

#set the keyvault
$keyVaultName = "wssecurity$deploymentId-kv";
Set-AzKeyVaultAccessPolicy -ResourceGroupName $resourceGroupName -VaultName $keyVaultName -UserPrincipalName $userName -PermissionsToSecrets get,list,set,delete,backup,restore,recover,purge -PermissionsToKeys decrypt,encrypt,unwrapKey,wrapKey,verify,sign,get,list,update,create,import,delete,backup,restore,recover,purge -PermissionsToCertificates get,list,delete,create,import,update,managecontacts,getissuers,listissuers,setissuers,deleteissuers,manageissuers,recover,purge,backup,restore

sleep 20

Stop-Transcript