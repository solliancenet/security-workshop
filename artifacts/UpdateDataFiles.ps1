#update all data to today's date

function UpdateFile($fileName, $tokens)
{
    $content = Get-Content $fileName -raw

    foreach($key in $tokens.keys)
    {
        $content = $content.replace($key,$tokens[$key]);
    }
}

$ht = new-object System.Collections.Hashtable;
$ht.add("#TODAY#",[DateTime]::NOW.ToString("YYYY-mm-DD"));
$ht.add("#TIMESTAMP#",[DateTime]::NOW.tostring("YYYY-mm-DD HH:MM:SS"));
$ht.add("#WORKSPACE_ID#", "#IN_WORKSPACE_ID#");
$ht.add("#SUBSCRIPTION_ID#", "#IN_SUBSCRIPTION_ID#");
$ht.add("#RESOURCE_GROUP_NAME#", "#IN_RESOURCE_GROUP_NAME#");
$ht.add("#DEPLOYMENT_ID#", "#IN_DEPLOYMENT_ID#");
$ht.add("#WAF_IP#", "#IN_WAF_IP#");
$ht.add("#APP_SVC_URL#", "#IN_APP_SVC_URL#");
$ht.add("#IP#", "203.160.71.100");

UpdateFile "logfile.txt" $ht;
UpdateFile "logs.json" $ht;
UpdateFile "webattack.ps1" $ht;
UpdateFile "./logs-01/logs-01.log" $ht;
UpdateFile "./logs-01/logs-02.log" $ht;
UpdateFile "./logs-02/logs-03.log" $ht;
UpdateFile "./logs-02/logs-04.log" $ht;