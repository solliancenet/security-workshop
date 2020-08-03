$global:headers = new-object system.collections.hashtable;
$global:urlCookies = new-object System.Collections.Hashtable;

function GetCookies($url)
{
    $u = new-object Uri($url);

    if ($global:urlCookies.Contains($u.Host))
    {
        return $(FormatCookie $global:urlCookies[$u.Host]);
    }

    return "";
}

function FormatCookie($ht)
{
    $cookie = "";

    foreach ($key in $ht.Keys)
    {
        $cookie += $key.Trim() + "=" + $ht[$key] + "; ";
    }

    return $cookie;
}

function DoGet($url, $strCookies)
{    
    $cookies = new-object system.net.CookieContainer;
    $uri = new-object uri($url);
    $httpReq = [system.net.HttpWebRequest]::Create($uri)
    $httpReq.Accept = "text/html, application/xhtml+xml, */*"
    $httpReq.method = "GET"   
    
    if ($global:httptimeout)
    {        
        $httpReq.Timeout = $global:httptimeout;
    }

    if ($global:language)
    {
        $httpReq.Headers["Accept-Language"] = $global:language;
        $global:language = $Null;
    }

    if ($global:useragent)
    {
        $httpReq.useragent = $global:useragent;
        $global:useragent = $null;
    }
    else
    {
        $httpReq.useragent = "Mozilla/5.0 (Windows NT 6.3; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/60.0.3112.113 Safari/537.36";
    }

    if ($global:referer)
    {
        $httpReq.Referer = $global:referer;
        $global:referer = $null;
    }

    if ($global:accept)
    {
        $httpReq.Accept = $global:accept;
        $global:accept = $null;
    }

    if ($global:connection)
    {
        $httpReq.keepalive = $true;     
        $global:connection = $null;
    }
    
    $httpReq.AllowAutoRedirect = $global:allowautoredirect;    
    
    #allow us to override the cookies if we have done so...
    if ($strCookies.length -gt 0)
    {
        $httpReq.Headers.add("Cookie", $strCookies);
    }
    else
    {
        $cookie = GetCookies($url);

        if (![string]::IsNullOrEmpty($cookie))
        {
            $httpreq.Headers.Add("Cookie", $cookie);
        }    
    }

    foreach($key in $global:headers.keys)
    {
        $httpReq.Headers.add($key, $global:headers[$key]);
    }

    $global:headers.Clear();

    if ($url.contains(".mp4"))
    {
        write-host $url;
    }

    if ($url.contains("post"))
    {
        write-host $url;
    }

    if (!$url.endswith(".mp4#_=_"))
    {
        #clear the buffer...
        $global:fileBuffer = $null;  
        $global:currentMark = 0; 
        $global:nextMark = 0;
    }

    if (($url.endswith(".mp4#_=_") -and ($global:currentMark -eq 0 -or $global:currentMark -eq $null)) -or $global:doChucks)
    {
        [int]$global:currentMark = 0; #MB
        [int]$global:nextMark = 0 + [int]$global:videoBuffer #1MB;
    }

    if (($url.endswith(".mp4#_=_") -or $global:doChucks) -and $global:nextMark -ne 0)
    {        
        #add the extra headers to download a part of the file...
        $httpReq.addrange("bytes",$global:currentMark,$global:nextMark);
    }

    [string]$results = ProcessResponse $httpReq;    

    if ($global:contentRange)
    {
        if ($global:nextMark -eq $global:maxMark-1)
        {
            return;
        }

        $vals = $global:contentRange.replace("bytes","").split("-");
        $global:lastMark = $vals[0];        
        $vals = $vals[1].split("/");
        [int]$global:currentMark = $vals[0];
        [int]$global:maxMark = $vals[1];

        #set the current marks...
        [int]$global:currentMark += 1;
        [int]$global:nextMark += [int]$global:videoBuffer;

        if ($global:nextMark -ge $global:maxMark-1)
        {
            $global:nextMark = $global:maxMark-1;
            $global:done = $true;
        }

        DoGet $url $strCookies;

        if ($global:done)
        {
            $global:contentRange = $null;
            return;
        }
    }
    else
    {
        $global:currentMark = $null;
    }
    
    return $results
}

$global:fileName = ""
$global:fileBuffer = $null;

$global:videoMaxSize = 2000000;  #2MB download at a time...
$global:videoPointer = 0;

$global:location = "";

$global:contentRange = "";

function ProcessResponse($req)
{
    $global:httpCode = -1;
    $global:fileName = ""
    #$global:fileBuffer = $null;    

    $urlFileName = $req.RequestUri.Segments[$req.RequestUri.Segments.Length - 1];            
    $response = "";            

    try
    {
        $res = $req.GetResponse();

        $mimeType = $res.ContentType;
        $statusCode = $res.StatusCode.ToString();
        $global:httpCode = [int]$res.StatusCode;
        $cookieC = $res.Cookies;
        $resHeaders = $res.Headers;  
        $global:rescontentLength = $res.ContentLength;
                                
        try
        {
            $global:location = $res.Headers["Location"].ToString();
        }
        catch
        {
        }

        try
        {
            $global:contentRange = $res.Headers["Content-Range"].ToString();

            $vals = $global:contentRange.replace("bytes","").split("-");
            $global:lastMark = $vals[0];        
            $vals = $vals[1].split("/");
            $global:currentMark = $vals[0];
            $global:maxMark = $vals[1];

            #set the content length...
            $global:rescontentLength = $global:maxMark;
        }
        catch
        {
        }

        try
        {
            $rawCookies = $res.Headers["set-cookie"].ToString();

            SetCookiesUnformatted $res.ResponseUri.ToString() $rawCookies;
        }
        catch 
        {
        }

        $global:fileName = "";
        $length = 0;

        try
        {
            $global:fileName = $res.Headers["Content-Disposition"].ToString();

            if ($global:fileName -ne "attachment")
            {
                $global:fileName = $global:fileName.Replace("attachment; filename=", "").Replace("""", "");

                if ($global:filename.contains("filename="))
                {
                    $global:filename = ParseValue $global:fileName "filename=" ";";
                }

                $length = $res.ContentLength;
            }
            else
            {
                $global:fileName = "";
            }
        }
        catch
        {

        }        

        if ($global:fileName.Length -gt 0)
        {
            $bufferSize = 10240;
            $buffer = new-object byte[] $buffersize;

            $strm = $res.GetResponseStream();  
            
            if ($global:fileBuffer -eq $Null)
            {          
                $global:bytesRead = 0;
                $global:fileBuffer = new-object byte[] $($res.ContentLength);
                $global:ms = new-object system.io.MemoryStream (,$global:fileBuffer);
            }
            
            while (($bytesRead = $strm.Read($buffer, 0, $bufferSize)) -ne 0)
            {
                $global:ms.Write($buffer, 0, $bytesRead);
            } 

            $global:ms.Close();
            $strm.Close();
        }
        else
        {
            $responseStream = $res.GetResponseStream();
            $contentType = $res.Headers["Content-Type"];

            if ($res.ContentEncoding.ToLower().Contains("gzip"))
            {
                $responseStream = new-object System.IO.Compression.GZipStream($responseStream, [System.IO.Compression.CompressionMode]::Decompress);
            }
            
            if ($res.ContentEncoding.ToLower().Contains("deflate"))
            {
                $responseStream = new-object System.IO.Compression.DeflateStream($responseStream, [System.IO.Compression.CompressionMode]::Decompress);
            }

            switch($contentType)
            {
                {$_ -in "image/gif","image/png","image/jpeg","video/mp4"}
                {
                    $bufferSize = 409600;
                    $buffer = new-object byte[] $buffersize;                                        
                    $bytesRead = 0;

                    if ($global:fileBuffer -eq $Null)
                    {          
                        $global:bytesRead = 0;
                        $global:fileBuffer = new-object byte[] $($global:rescontentlength);
                        $global:ms = new-object system.io.MemoryStream (,$global:fileBuffer);
                    }
                                        
                    while (($bytesRead = $responseStream.Read($buffer, 0, $bufferSize)) -ne 0)
                    {
                        $global:ms.Write($buffer, 0, $bytesRead);
                        $global:bytesRead += $bytesRead;
                    } 
                    
                    <#
                    if ($global:bytesRead -eq $global:maxMark)
                    {
                        #$global:ms.Close();
                    }
                    #>

                    $responseStream.Close();

                    if ($global:fileName.Length -eq 0)
                    {                        
                        $global:fileName = $req.requesturi.segments[$req.requesturi.segments.length-1];

                        if ($contentType -eq "video/mp4")
                        {
                            $global:fileName += ".mp4";
                        }
                    }

                    }
                default{
                    $reader = new-object system.io.StreamReader($responseStream, [System.Text.Encoding]::Default);                    
                    $response = $reader.ReadToEnd();                            
                    }
            }

            $res.Close();
            $responseStream.Close();

            $req = $null;
            $proxy = $null;
        }
    }
    catch
    {
        $res = $_.Exception.InnerException.Response;

        $global:contentRange = $null;

        try
        {
            $responseStream = $res.GetResponseStream();
            $statusCode = $res.StatusCode.ToString();
            $global:httpCode = [int]$res.StatusCode;
            $reader = new-object system.io.StreamReader($responseStream, [System.Text.Encoding]::Default);                    
            $response = $reader.ReadToEnd();                            
            return $response;
        }
        catch
        {
            $global:httperror = $_.exception.message;

            write-host "Error getting response from $($req.RequestUri)";
            return $null;
        }

        if ($res.ContentEncoding.ToLower().Contains("gzip"))
        {
            $responseStream = new GZipStream($responseStream, [System.IO.Compression.CompressionMode]::Decompress);
        }
        
        if ($res.ContentEncoding.ToLower().Contains("deflate"))
        {
            $responseStream = new DeflateStream($responseStream, [System.IO.Compression.CompressionMode]::Decompress);
        }

        $reader = new-object System.IO.StreamReader($responseStream, [System.Text.Encoding]::Default);
        $response = $reader.ReadToEnd();                
    }    

    return $response;
}

$contentType = "application/x-www-form-urlencoded"
$overrideContentType = $null
$useXRequestWith = $false

function DoHttpSendAction($action, $url, $post, $strCookies )
{
    $encoding = new-object system.text.asciiencoding
    $buf = $encoding.GetBytes($post)
    $uri = new-object uri($url);
    $httpReq = [system.net.HttpWebRequest]::Create($uri)
    $httpReq.AllowAutoRedirect = $false
    $httpReq.method = $action;
    #$httpReq.Referer = ""
    $httpReq.contentlength = $buf.length

    $httpReq.Accept = "text/html, application/xhtml+xml, */*"
    #$httpReq.ContentType = "application/x-www-form-urlencoded"
    $httpReq.headers.Add("Accept-Language", "en-US")
    $httpReq.UserAgent = "Mozilla/5.0 (compatible; MSIE 9.0; Windows NT 6.1; WOW64; Trident/5.0; LEN2)"

    #allow us to override the cookies if we have done so...
    if ($strCookies)
    {
        $httpReq.Headers.add("Cookie", $strCookies);
    }
    else
    {
        $cookie = GetCookies($url);

        if (![string]::IsNullOrEmpty($cookie))
        {
            $httpreq.Headers.Add("Cookie", $cookie);
        }    
    }

    if ($global:referer)
    {
        $httpReq.Referer = $global:referer;
        $global:referer = $null;
    }

    if ($global:useragent)
    {
        $httpReq.useragent = $global:useragent;
        $global:useragent = $null;
    }
    
    if ($global:overrideContentType)
    {
        $httpReq.ContentType = $overrideContentType
        $global:overrideContentType = $null
    }
    else
    {
        $httpReq.ContentType = "application/x-www-form-urlencoded"
    }

    if ($digest)
    {
        $httpReq.headers.Add("X-RequestDigest", $digest)
    }

    if ($useXRequestWith)
    {
        $httpReq.headers.Add("X-Requested-With", "XMLHttpRequest")
        $useXRequestWith = $false
    }

    foreach($key in $global:headers.keys)
    {
        $httpReq.Headers.add($key, $global:headers[$key]);
    }

    $global:headers.Clear();
    
    $stream = $httpReq.GetRequestStream()

    [void]$stream.write($buf, 0, $buf.length)
    $stream.close()

    [string]$results = ProcessResponse $httpReq;       

    return $results
}

function DoPost($url, $post, $strCookies )
{    
    DoHttpSendAction "POST" $url $post $strCookies
}

function DoPut($url, $post, $strCookies )
{    
    DoHttpSendAction "PUT" $url $post $strCookies
}

function Attack_HostHeaderIP($ipAddress)
{
	$html = DoGet "http://$ipAddress";
}

function Attack_SecurityScannerUserAgent($url)
{
	#known bad user agent string...	
	$global:userAgent = "Mozilla/4.0 (compatible; MSIE 6.0; Windows NT 5.2; .NET CLR 1.0.3705";
	$html = DoGet $url;

    #known bad user agent string...	
	$global:userAgent = "s.t.a.l.k.e.r.";
	$html = DoGet $url;

    #known bad user agent string...	
	$global:userAgent = "prog.customcrawler";
	$html = DoGet $url;
}

function Attack_SessionFixaction($url)
{	
    $tempurl = $url + "/;JSESSIONIS=1234"
	$html = DoGet $tempurl;

    $tempurl = $url + "/<script>document.cookie=`"sessionid=1234;%20domain=.example.dom`";</script>.idc"
	$html = DoGet $tempurl;
}

function Attack_SQLInjection($url)
{    
    $post = "username=tom' order by 8 -- +&submit=Submit";    
	$html = DoPost $url $post;
}

function Attack_XSS($url)
{
    $tempurl = $url + "/<script>alert(`"TEST`");</script>";
    $html = DoGet $tempurl;

    $url = $url;
    $post = "<script>alert(`"TEST`");</script>";
    $html = DoPost $url $post;
}

#Learn more about the rules here : https://github.com/SpiderLabs/owasp-modsecurity-crs/tree/v3.0/master/rules

$ipAddress = read-host "what is your waf ip?";
$url = read-host "what is your url";

Attack_HostHeaderIP $ipAddress;

Attack_SecurityScannerUserAgent $url;

Attack_SessionFixaction $url;

Attack_SQLInjection $url;

Attack_XSS $url;