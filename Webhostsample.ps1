$Powershell = [PowerShell]::Create()
$PowerShell.AddScript({
    $HttpListener = New-Object System.Net.HttpListener
    $HttpListener.Prefixes.Add('http://172.20.16.68:5002/')
    $HttpListener.Start()
    do {
        $Context = $HttpListener.GetContext()
        $Context.Response.StatusCode = 200
        $Context.Response.ContentType = 'application/json'
        $WebContent =  '{"big": "test"}'
        $EncodingWebContent = [System.Text.Encoding]::UTF8.GetBytes($WebContent)
        $Context.Response.OutputStream.Write($EncodingWebContent , 0, $EncodingWebContent.Length)
        $Context.Response.Close()
        Write-Host "." -NoNewLine
    } until ([System.Console]::KeyAvailable)
})
$Webserver = $PowerShell.BeginInvoke() 