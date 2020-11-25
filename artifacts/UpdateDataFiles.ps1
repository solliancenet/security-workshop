#update all data to today's date

function UpdateFile($fileName, $tokens)
{
    $content = Get-Content $fileName -raw

    if ($content)
    {
        foreach($key in $tokens.keys)
        {
            $content = $content.replace($key,$tokens[$key]);
        }
    }

    Set-Content $fileName $content;
}

cd C:\LabFiles\security-workshop\artifacts

$ht = new-object System.Collections.Hashtable;
$ht.add("#TODAY#",[DateTime]::NOW.ToString("yyyy-MM-dd"));
$ht.add("#TOMORROW#",[DateTime]::NOW.AddDays(1).ToString("yyyy-MM-dd"));
$ht.add("#YESTERDAY#",[DateTime]::NOW.AddDays(-1).ToString("yyyy-MM-dd"));
$ht.add("#TWODAYSAGO#",[DateTime]::NOW.AddDays(-2).ToString("yyyy-MM-dd"));
$ht.add("#TIMESTAMP#",[DateTime]::NOW.tostring("yyyy-MM-dd HH:MM:SS"));
$ht.add("#WORKSPACE_NAME#", "#IN_WORKSPACE_NAME#");
$ht.add("#WORKSPACE_ID#", "#IN_WORKSPACE_ID#");
$ht.add("#WORKSPACE_KEY#", "#IN_WORKSPACE_KEY#");
$ht.add("#SUBSCRIPTION_ID#", "#IN_SUBSCRIPTION_ID#");
$ht.add("#RESOURCE_GROUP_NAME#", "#IN_RESOURCE_GROUP_NAME#");
$ht.add("#DEPLOYMENT_ID#", "#IN_DEPLOYMENT_ID#");
$ht.add("#WAF_IP#", "#IN_WAF_IP#");
$ht.add("#APP_SVC_URL#", "#IN_APP_SVC_URL#");
$ht.add("#IP_1#", "203.160.71.100");
$ht.add("#IP_2#", "80.89.137.214");
$ht.add("#IP_3#", "117.82.191.160");

UpdateFile "logfile.txt" $ht;
UpdateFile "DataCollector.ps1" $ht;
UpdateFile "host_logins.csv" $ht;
UpdateFile "logs.json" $ht;
UpdateFile "Azure Sentinel ML.ipynb" $ht;
UpdateFile "aad_logons.pkl" $ht;
UpdateFile "webattack.ps1" $ht;
UpdateFile "./logs-01/logs-01.log" $ht;
UpdateFile "./logs-01/logs-02.log" $ht;
UpdateFile "./logs-02/logs-03.log" $ht;
UpdateFile "./logs-02/logs-04.log" $ht;