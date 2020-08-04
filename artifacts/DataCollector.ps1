# Create the function to create the authorization signature
Function Build-Signature ($customerId, $sharedKey, $date, $contentLength, $method, $contentType, $resource)
{
    $xHeaders = "x-ms-date:" + $date
    $stringToHash = $method + "`n" + $contentLength + "`n" + $contentType + "`n" + $xHeaders + "`n" + $resource

    $bytesToHash = [Text.Encoding]::UTF8.GetBytes($stringToHash)
    $keyBytes = [Convert]::FromBase64String($sharedKey)

    $sha256 = New-Object System.Security.Cryptography.HMACSHA256
    $sha256.Key = $keyBytes
    $calculatedHash = $sha256.ComputeHash($bytesToHash)
    $encodedHash = [Convert]::ToBase64String($calculatedHash)
    $authorization = 'SharedKey {0}:{1}' -f $customerId,$encodedHash
    return $authorization
}


# Create the function to create and post the request
Function Post-LogAnalyticsData($workspaceId, $key, $body, $logType)
{
    $method = "POST"
    $contentType = "application/json"
    $resource = "/api/logs"
    $rfc1123date = [DateTime]::UtcNow.ToString("r")
    $contentLength = $body.Length
    $signature = Build-Signature `
        -customerId $workspaceId `
        -sharedKey $key `
        -date $rfc1123date `
        -contentLength $contentLength `
        -method $method `
        -contentType $contentType `
        -resource $resource
    $uri = "https://" + $workspaceId + ".ods.opinsights.azure.com" + $resource + "?api-version=2016-04-01"

    $headers = @{
        "Authorization" = $signature;
        "Log-Type" = $logType;
        "x-ms-date" = $rfc1123date;
        "time-generated-field" = $TimeStampField;
    }

    $response = Invoke-WebRequest -Uri $uri -Method $method -ContentType $contentType -Headers $headers -Body $body -UseBasicParsing
    return $response.StatusCode

}

# Replace with your Workspace ID
$workspaceId = "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
$workspaceId = "ffe8f243-3ec8-465c-8648-14fea7a7f9ba";

# Replace with your Primary Key
$key = "xxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"
$key = "nLJiPZZYE241/ndD/+STnN/v+Wbxu2iyc8duk3zQmSpjzOQYpxnTq15PMhFCPu1xGq13u6sWcts1xsydXNt67g==";

# Specify the name of the record type that you'll be creating
$LogType = "MyRecordType"

# You can use an optional field to specify the timestamp from the data. If the time field is not specified, Azure Monitor assumes the time is the message ingestion time
$TimeStampField = "DateValue"

# Create two records with the same set of properties to create
$json = @"
[{  "StringValue": "MyString1",
    "NumberValue": 42,
    "SourceSystem": "OpsManager",
    "BooleanValue": true,
    "IsThreat": true,
    "ManagementGroupName": "AOI-ffe8f243-3ec8-465c-8648-14fea7a7f9ba",
    "DateValue": "2020-08-03T20:00:00.625Z",
    "GUIDValue": "9909ED01-A74C-4874-8ABF-D2678E3AE23D",
    "Computer" : "paw-1",
    "IPAddress" : "10.0.0.5",
    "ResourceId" : "/subscriptions/e433f371-e5e9-4238-abc2-7c38aa596a18/resourcegroups/cjg-security/providers/microsoft.compute/virtualmachines/wssecuritycjg12345-paw-1"
},
{   "StringValue": "MyString2",
    "NumberValue": 43,
    "SourceSystem": "OpsManager",
    "BooleanValue": false,
    "IsThreat": false,
    "ManagementGroupName": "AOI-ffe8f243-3ec8-465c-8648-14fea7a7f9ba",
    "DateValue": "2020-08-03T20:00:00.625Z",
    "GUIDValue": "8809ED01-A74C-4874-8ABF-D2678E3AE23D",
    "Computer" : "paw-1",
    "IPAddress" : "10.0.0.5",
    "ResourceId" : "/subscriptions/e433f371-e5e9-4238-abc2-7c38aa596a18/resourcegroups/cjg-security/providers/microsoft.compute/virtualmachines/wssecuritycjg12345-paw-1"
}]
"@

# Submit the data to the API endpoint
Post-LogAnalyticsData -workspaceId $workspaceId -key $key -body ([System.Text.Encoding]::UTF8.GetBytes($json)) -logType $logType

