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
$ht.add("#TIMESTAMP#",[DateTime]::NOW);
$ht.add("#SUBSCRIPTION_ID#", "");
$ht.add("#RESOURCE_GROUP_NAME#", "");
$ht.add("#IP#", "203.160.71.100");

UpdateFile "logfile.txt" $ht;
UpdateFile "logs.json" $ht;