
$Token = Confirm-VolvoAuthentication

$CarData = Invoke-WebRequest `
-Uri ("https://api.volvocars.com/energy/v1/vehicles/$($Config.'Car.Vin' | ConvertFrom-SecureString -AsPlainText)/recharge-status") `
-Method 'get' `
-Headers @{
    'vcc-api-key' = $Config.'Credentials.VccApiKey' | ConvertFrom-SecureString -AsPlainText
    'content-type' = 'application/json'
    'accept' = '*/*'
    'authorization' = ('Bearer ' + ($Token.AccessToken | ConvertFrom-SecureString -AsPlainText))
}

$CarDataJson = ($CarData.RawContent -split '(?:\r?\n){2,}')[1]

$global:MyData = [hashtable]::Synchronized(@{})
$global:OutputData = [hashtable]::Synchronized(@{})
   
$MyData.add("CarData", $CarDataJson)

$Runspace = @{}
$Runspace.runspace = [RunspaceFactory]::CreateRunspace()
$Runspace.runspace.ApartmentState = "STA"
$Runspace.runspace.ThreadOptions = "ReuseThread" 
#open runspace
$Runspace.runspace.Open()
$Runspace.psCmd = [PowerShell]::Create() 
$Runspace.runspace.SessionStateProxy.SetVariable("MyData",$MyData)
$Runspace.runspace.SessionStateProxy.SetVariable("OutputData",$OutputData)
$Runspace.psCmd.Runspace = $Runspace.runspace 

#add the scipt to the runspace
$Runspace.Handle = $Runspace.psCmd.AddScript({  
    $HttpListener = New-Object System.Net.HttpListener
    $HttpListener.Prefixes.Add('http://*:5002/')
    $HttpListener.Start()
    do {
        $Context = $HttpListener.GetContext()
        $Context.Response.StatusCode = 200
        $Context.Response.ContentType = 'application/json'
        $WebContent =  $MyData.Cardata
        $EncodingWebContent = [System.Text.Encoding]::UTF8.GetBytes($WebContent)
        $Context.Response.OutputStream.Write($EncodingWebContent , 0, $EncodingWebContent.Length)
        $Context.Response.Close()
        Write-Host "." -NoNewLine
    } until ([System.Console]::KeyAvailable)
}).BeginInvoke()