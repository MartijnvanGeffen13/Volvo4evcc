Function Load-TokenFromDisk
{
<#
	.SYNOPSIS
		Load Token data from disk, decrypt and convert to secure credential
	
	.DESCRIPTION
		Load Token data from disk, decrypt and convert to secure credential
	
	.EXAMPLE
		Load-TokenFromDisk
#>

    [CmdletBinding()]
    Param (       	
    )

    $Token = @{}
    If (Test-Path -Path './EncryptedOAuthToken.xml') {
        $Token = Import-Clixml -Path './EncryptedOAuthToken.xml'
    }else {
        Write-Debug -Message 'Access Token Not found on disk'
        [String]$Token.AccessToken = 'Not Found on Disk'
    }
    If ($Token.AccessToken -ne 'Not Found on Disk'){
        $Token.Source = 'Disk'

        If ($Token.ValidTimeToken -lt (Get-date)){
            $Token.Source = 'Invalid-Expired'
            Write-Debug -Message 'Token is expired'
        }
    }else{
        $Token.Source = 'Invalid'
        Write-Debug -Message 'Passing invalid Token state'
    }    
            
    return $Token
}

Function Initialize-VolvoAuthenticationOtpRequest
{
<#
	.SYNOPSIS
		Start a new authentication setting validating full authentication
	
	.DESCRIPTION
		Start a new authentication setting validating full authentication
	
	.EXAMPLE
		Initialize-VolvoAuthentication
#>

    [CmdletBinding()]
    Param (       	
    )

    #Test if we loaded config allready if not load now
    $Global:Config = Import-ConfigVariable
    

    $StartHeader = @{
  
        'authorization' = 'Basic aDRZZjBiOlU4WWtTYlZsNnh3c2c1WVFxWmZyZ1ZtSWFEcGhPc3kxUENhVXNpY1F0bzNUUjVrd2FKc2U0QVpkZ2ZJZmNMeXc='
        'User-Agent' = 'volvo4evcc'
        'lang' ='en'
        'country'='us'
        'Accept-Encoding' = 'gzip'
        'content-type'= 'application/json; charset=utf-8'
    }

    $Header = Set-Header -HeaderParameter $StartHeader

    #This should be the very first call to the service so we store it in a session variable for automatic handeling of the cookies
    Write-Debug -Message "Initiate first web auth with claims to $(($Global:Config.'Url.Oauth_Authorise'+$Global:Config.'Url.Oauth_Claims'))"
    $AuthenticationFirstRequestRaw = Invoke-WebRequest -Uri ($Global:Config.'Url.Oauth_Authorise'+$Global:Config.'Url.Oauth_Claims') -Headers $Header -Method 'get' -SessionVariable AuthenticationRawSession
    $AuthenticationFirstRequestJson = $AuthenticationFirstRequestRaw.Content | ConvertFrom-Json
    
    #Add required header for CheckUsernamePassword
    $Header = Set-Header -CurrentHeader $Header -HeaderParameter @{'x-xsrf-header'='PingFederate'}

    $CheckUsernamePasswordUrl = $AuthenticationFirstRequestJson._links.checkUsernamePassword.href + '?action=checkUsernamePassword'

    #Purge Auth variable data from memory
    Remove-Variable -Name AuthenticationFirstRequestJson
    Remove-Variable -Name AuthenticationFirstRequestRaw

    #Query URL without exposing a cred as variable
    Write-Debug -Message "Initiate authentication with username and password to get OTP emailed"
    $AuthenticationOtpReceived = Invoke-WebRequest `
    -Uri $CheckUsernamePasswordUrl `
    -Method 'post' `
    -Body (@{
        'username' = $Global:Config.'Credentials.Username' | ConvertFrom-SecureString -AsPlainText
        'password' = $Global:Config.'Credentials.Password' | ConvertFrom-SecureString -AsPlainText
    } | ConvertTo-Json) `
    -WebSession $AuthenticationRawSession `
    -Headers $Header

    $AuthenticationOtpReceivedJson = $AuthenticationOtpReceived.content | ConvertFrom-Json

    $AuthReturnObject = @{

        'CheckOtpUrl' =  $AuthenticationOtpReceivedJson._links.checkOtp.href + '?action=checkOtp'
        'Websession' = $AuthenticationRawSession
        'Header' = $Header

    }

    Return $AuthReturnObject
}


Function Set-Header
{
<#
	.SYNOPSIS
		Compare 2 headers
	
	.DESCRIPTION
		Compare 2 headers and update the old one with new values or merge
	
	.EXAMPLE
		Set-Header -CurrentHeader $Header -HeaderParameter $Global:Config
#>

    [CmdletBinding()]
    Param (
        
        [Parameter(Mandatory=$False)]
        [Hashtable]$CurrentHeader,

        [Parameter(Mandatory=$true)]
        [Hashtable]$HeaderParameter
    )

    If ($PSBoundParameters.ContainsKey('CurrentHeader')){

        foreach ($Key in $HeaderParameter.Keys)
        {
            If ($key -in $CurrentHeader.Keys){

                $CurrentHeader.$Key = $HeaderParameter.$Key

            }else{
            
                $CurrentHeader.Add($Key,$HeaderParameter.$Key)
            }

        }
        $NewHeader = $CurrentHeader
    }else{
        $NewHeader = $HeaderParameter        
    }

    return $NewHeader

}

Function Wait-UserOtpInput
{
<#
	.SYNOPSIS
		While the system has generated a OTP request we now need the user to provide it 
        We will wait and attempt to harver the token for 5 minutes
	
	.DESCRIPTION
		While the system has generated a OTP request we now need the user to provide it 
        We will wait and attempt to harver the token for 5 minutes
	
	.EXAMPLE
		Wait-UserOtpInput
#>

    [CmdletBinding()]
    Param (       	
    )

    $Otp = Read-Host -AsSecureString -Prompt 'Please provide the OTP code sent to your email'

    return $Otp
}


Function Import-ConfigVariable
{
<#
	.SYNOPSIS
		Import configuration form disk
	
	.DESCRIPTION
		Import configuration form disk

	.EXAMPLE
		Import-ConfigVariable
#>
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory=$False)]
        [Switch]$Reload
    )

    If ($Reload){
        If (Test-Path -Path "$((Get-Location).path)\volvo4evccconfig.xml" ) {
            $Global:Config = Import-Clixml -Path "$((Get-Location).path)\volvo4evccconfig.xml" -ErrorAction SilentlyContinue
            return $Global:Config
        }else{
            Throw 'Please run Set-VolvoAuthentication first to configure this module'
        }
    }

    If ($Global:Config){
        If (-not($Global:Config.'credentials.username')){

            #Force reload attempt from config
            If (Test-Path -Path "$((Get-Location).path)\volvo4evccconfig.xml" ) {
                $Global:Config = Import-Clixml -Path "$((Get-Location).path)\volvo4evccconfig.xml" -ErrorAction SilentlyContinue
            }else{
                Throw 'Please run Set-VolvoAuthentication first to configure this module'
            }
            
            #Test again on reload
            If (-not($Global:Config.'credentials.username')){
                Write-Debug -Message 'Config variable found but no username key present after force reload'
                Throw 'Please run Set-VolvoAuthentication first to configure this module'
            }
        }
    }else{
        If (Test-Path -Path "$((Get-Location).path)\volvo4evccconfig.xml"){
            Write-Debug -Message "$((Get-Location).path)\volvo4evccconfig.xml not found"
            $Global:Config = Import-Clixml -Path "$((Get-Location).path)\volvo4evccconfig.xml"
        }else{
            Write-Debug -Message 'volvo4evccconfig.xml Does not exist'
            Throw 'Please run Set-VolvoAuthentication first to configure this module'
        }        
    }

    return $Global:Config
}

Function Initialize-VolvoAuthenticationTradeOtpForOauth
{
<#
	.SYNOPSIS
		This will take the web session from the OTP, and the OTP URL as input and will trade the OTP for a Oauth token
	
	.DESCRIPTION
		Trade OTP for Oauth token

	.EXAMPLE
		Initialize-VolvoAuthenticationTradeOtpForOauth -AuthReturnObject $AuthReturnObject
#>
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory=$true)]
        [hashtable]$AuthReturnObject
    )

    #Create new header variable so we can get rid of the hash table
    $Header = $AuthReturnObject.Header  
    $AuthenticationRawSession = $AuthReturnObject.Websession

    $BodyOtp = @{'otp'= $Global:Config.'Credentials.otp'} | ConvertTo-Json

    #reset the OTP token on disk
    Set-VolvoAuthentication -ResetOtpToken

    $AuthenticationRequestSendOtp = Invoke-WebRequest -Uri $AuthReturnObject.CheckOtpUrl -Method 'post' -Body $BodyOtp -WebSession $AuthenticationRawSession -Headers $Header
    Write-Debug -Message "OTP sent to server"
   
    #Clean up variables used with OTP data
    Remove-Variable -Name 'BodyOtp'
    Remove-Variable -Name 'AuthReturnObject'

    $AuthenticationRequestSendOtpJson = $AuthenticationRequestSendOtp.Content | ConvertFrom-Json
    $ContinueAuthenticationUrl = $AuthenticationRequestSendOtpJson._links.continueAuthentication.href + '?action=continueAuthentication'
    
    #Clean up variables used with OTP data
    Remove-Variable -Name AuthenticationRequestSendOtp

    Try{
        #Not the best way to harvest the code but it will do for now as we need it encrypted
        $AuthenticationAuthorizationCodeUnEncrypted = Invoke-WebRequest -Uri $ContinueAuthenticationUrl -Method 'get' -WebSession $AuthenticationRawSession -Headers $Header
        $AuthenticationAuthorizationCodeEncrypted = ($AuthenticationAuthorizationCodeUnEncrypted.Content | ConvertFrom-Json).authorizeResponse.code | ConvertTo-SecureString -AsPlainText
        Remove-variable -Name AuthenticationAuthorizationCodeUnEncrypted
        Write-Debug -Message "Completed Authentication"
    }catch {
        Write-Debug -Message "Failed to securely harvest the authorization code"
        Throw $_.Exception.Message
    }
    
    #Get Oauth
    Write-Debug -Message "Preparing Oauth request"

    $Header = Set-Header -CurrentHeader $Header -HeaderParameter @{'content-type' = 'application/x-www-form-urlencoded'}

    $AuthenticationRequestOauth = Invoke-WebRequest `
    -Uri $Global:Config.'Url.Oauth_Token' `
    -Method 'post' `
    -Body @{
        'code' = $AuthenticationAuthorizationCodeEncrypted | ConvertFrom-SecureString -AsPlainText
        'grant_type' = 'authorization_code'
     } `
    -WebSession $AuthenticationRawSession `
    -Headers $Header

    $AuthenticationRequestOauthJson =  $AuthenticationRequestOauth.Content | ConvertFrom-Json

    #store
    $Token = @{}
    $Token.AccessToken = $AuthenticationRequestOauthJson.access_token |ConvertTo-SecureString -AsPlainText
    $Token.RefreshToken = $AuthenticationRequestOauthJson.refresh_token |ConvertTo-SecureString -AsPlainText
    $Token.ValidTimeToken = (Get-Date).AddSeconds( $AuthenticationRequestOauthJson.expires_in -120 )
    $Token.Source = 'Fresh'
    #Dont need the session anymore
    #$Token.Websession = $AuthenticationRawSession

    $Token | Export-Clixml -Path './EncryptedOAuthToken.xml'

    #Remove variables used during oauth request 
    Remove-Variable -Name AuthenticationRequestOauthJson
    Remove-Variable -Name AuthenticationRequestOauth

    return $Token
}


Function Start-RestBrokerService
{
<#
	.SYNOPSIS
		This will start the web broker on local host
	
	.DESCRIPTION
		This will start the web broker on local host using $Mydata and $OutputData as 
        synchronised hash tables 

	.EXAMPLE
		Start-RestBrokerSercive
#>
    [CmdletBinding()]
    Param (
    )

    $global:MyData = [hashtable]::Synchronized(@{})
    $global:OutputData = [hashtable]::Synchronized(@{})
    $global:Runspace = [hashtable]::Synchronized(@{})


    #On startup load last known data into web service
    If(Test-Path -Path './MyData.xml'){
        $global:MyData = Import-Clixml -Path './MyData.xml'
    }Else{
        $global:MyData.CarData = @"
{
    "status": 200,
    "data": {
        "estimatedChargingTime": {
            "value": "0",
            "unit": "minutes",
        },
        "batteryChargeLevel": {
            "value": "0",
            "unit": "percentage",
        },
        "electricRange": {
            "value": "0",
            "unit": "kilometers",
        },
        "chargingSystemStatus": {
            "value": "Startup",
        },
        "chargingConnectionStatus": {
            "value": "Startup",
        }
    },
    "operationId": "Startup"
}
"@
    }

    #$Runspace = @{}
    $Runspace.runspace = [RunspaceFactory]::CreateRunspace()
    $runspace.runspace.name = "Volvo4Evcc"
    $Runspace.runspace.ApartmentState = "STA"
    $Runspace.runspace.ThreadOptions = "ReuseThread" 
    #open runspace
    $Runspace.runspace.Open()
    $Runspace.psCmd = [PowerShell]::Create() 
    $Runspace.runspace.SessionStateProxy.SetVariable("MyData",$MyData)
    $Runspace.runspace.SessionStateProxy.SetVariable("OutputData",$OutputData)
    $Runspace.runspace.SessionStateProxy.SetVariable("Runspace",$Runspace)
    $Runspace.psCmd.Runspace = $Runspace.runspace 

    #add the scipt to the runspace
    $Runspace.Handle = $Runspace.psCmd.AddScript({  
        $HttpListener = New-Object System.Net.HttpListener
        $Runspace.HttpListener = $HttpListener
        $HttpListener.Prefixes.Add('http://*:6060/')
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
}

Function Reset-VolvoWebService
{
<#
	.SYNOPSIS
		Reset-VolvoWebService
	
	.DESCRIPTION
		Reset-VolvoWebService
	
	.EXAMPLE
		Reset-VolvoWebService
#>

    [CmdletBinding()]
    Param (       	
    )
    
    $OldRunspace = Get-Runspace -name Volvo4evcc
    If ($OldRunspace){
        $Runspace.HttpListener.Abort()
        $OldRunspace.Close()
        $OldRunspace.Dispose()
        [GC]::Collect()
        If ($PSVersionTable.OS -like "Microsoft*"){
            $LingeringObject = Get-NetTCPConnection -LocalPort 6060 -ea SilentlyContinue
            If ($LingeringObject){
                #Attempt retry
                $OldRunspace = Get-Runspace -name Volvo4evcc
                If ($OldRunspace){
                    $OldRunspace.Close()
                    $OldRunspace.Dispose()
                }
                [GC]::Collect()
                Start-Sleep -Seconds 2
                Start-RestBrokerService
            
            }
        }Else{
            Start-Sleep -Seconds 1
            Start-RestBrokerService
        }
    }else{
        Start-RestBrokerService
    }
}

Function Watch-VolvoCar
{
<#
	.SYNOPSIS
		This will start the web broker on local host
	
	.DESCRIPTION
		This will start the web broker on local host using $Mydata and $OutputData as 
        synchronised hash tables 

	.EXAMPLE
		Start-RestBrokerSercive
#>
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory=$true)]
        [hashtable]$Token
    )

    $CarData = Invoke-WebRequest `
    -Uri ("https://api.volvocars.com/energy/v1/vehicles/$($Global:Config.'Car.Vin' | ConvertFrom-SecureString -AsPlainText)/recharge-status") `
    -Method 'get' `
    -Headers @{
        'vcc-api-key' = $Global:Config.'Credentials.VccApiKey' | ConvertFrom-SecureString -AsPlainText
        'content-type' = 'application/json'
        'accept' = '*/*'
        'authorization' = ('Bearer ' + ($Token.AccessToken | ConvertFrom-SecureString -AsPlainText))
    }

    $CarDataJson = ($CarData.RawContent -split '(?:\r?\n){2,}')[1]
    $Global:MyData.CarData = $CarDataJson
    $Global:MyData | Export-Clixml -Path './MyData.xml'

}

Function Get-EvccData
{
<#
	.SYNOPSIS
		This will get the EVCC data 
	
	.DESCRIPTION
		This will get the EVCC data from your host to determine the intervalls 

	.EXAMPLE
		Get-EvccData
#>
    [CmdletBinding()]
    Param (
    )

    $EvccData = @{}

    Try {
        $EvccDataRaw = Invoke-RestMethod -Uri "$($Global:Config.'Url.evcc')/api/state"
        $EvccData.SourceOk = $True
    }catch{
        $EvccData.charging
        $EvccData.SourceOk = $False
    }

    $EvccData.Connected = $EvccDataRaw.result.loadpoints.connected
    $EvccData.Charging = $EvccDataRaw.result.loadpoints.charging

    return $EvccData
}

Function Get-NewVolvoToken
{
<#
	.SYNOPSIS
		If we have a expired token we could attempt the refresh token
	
	.DESCRIPTION
		If we have a expired token we could attempt the refresh token to get a new access token
	
	.EXAMPLE
		Get-NewVolvoToken -Token $Token
#>

    [CmdletBinding()]
    Param (     	
        [Parameter(Mandatory=$true)]
        [hashtable]$Token       
    
    )

    $Header = Set-Header -HeaderParameter @{
        'authorization' = 'Basic aDRZZjBiOlU4WWtTYlZsNnh3c2c1WVFxWmZyZ1ZtSWFEcGhPc3kxUENhVXNpY1F0bzNUUjVrd2FKc2U0QVpkZ2ZJZmNMeXc='
        'content-type' = 'application/x-www-form-urlencoded'
        'accept' = 'application/json'
    }

    Try {
        $NewTokenRaw = Invoke-WebRequest `
        -Uri $Global:Config.'Url.Oauth_Token'`
        -Method 'post' `
        -Headers $Header `
        -Body @{
            'grant_type' = 'refresh_token'
            'refresh_token' = $Token.RefreshToken | ConvertFrom-SecureString -AsPlainText     
        } 

        $NewToken = $NewTokenRaw.Content | ConvertFrom-Json

        $TempToken = @{}
        $TempToken.AccessToken = $NewToken.access_token |ConvertTo-SecureString -AsPlainText
        $TempToken.RefreshToken = $NewToken.refresh_token |ConvertTo-SecureString -AsPlainText
        $TempToken.ValidTimeToken = (Get-Date).AddSeconds( $NewToken.expires_in -120 )
        $TempToken.Source = 'Fresh'
        #Dont need the session anymore
        #$Token.Websession = $AuthenticationRawSession

        $TempToken | Export-Clixml -Path './EncryptedOAuthToken.xml'

    } Catch {
    
        Write-Debug -Message $ErrorMessage.ErrorDetails.Message
        $ErrorMessage = $_
        $Token.Source = 'Invalid-Expired'
        Return $Token
    }    

    Return $TempToken
}

Function Confirm-VolvoAuthentication
{
<#
	.SYNOPSIS
		Test if we still have valid cached tokens
	
	.DESCRIPTION
		Test if we still have valid cached tokens that can be reused after reboot etc
	
	.EXAMPLE
		Confirm-VolvoAuthentication
#>

    [CmdletBinding()]
    Param (       	
    )

    Try{
        $OauthToken = Load-TokenFromDisk
    } Catch {
        Write-Error -Message "$($_.Exception.Message)"
        Throw 'No token found on disk'
    }

    Try{
        $Global:Config = Import-ConfigVariable
    } Catch {
        Write-Error -Message "$($_.Exception.Message)"
        Throw 'Could not load config'
    }
    

    If ($OauthToken.Source -eq 'Disk'){
        Write-Debug -Message 'Token loaded from Disk succesfull'
        Return $OauthToken
    }

    #Retest if expired needs full auth flow due to test issiue last time a
    If ($OauthToken.Source -eq 'Invalid' -or $OauthToken.Source -eq 'Invalid-Expired'){
        Write-Debug -Message 'Token Cache issue need to refresh full token'
        Try{
            #Reset disk token to make sure its default
            Set-VolvoAuthentication -ResetOtpToken
            $OtpRequest = Initialize-VolvoAuthenticationOtpRequest
        } Catch {
            Write-Error -Message "$($_.Exception.Message)"
            Throw 'OTP Request failed'
        }
        
        Write-Host -ForegroundColor Yellow 'locate your email with the volvo token and run Set-VolvoAuthentication -OtpToken "<OTPcode>"'

        try{
            $Count =1
            Do {
                
                $Global:Config = Import-ConfigVariable -Reload
                Write-Host "Running wait for OTP loop $Count of 30"
                $Count++
                Write-Debug -Message  "Current OTP value: $($Global:Config.'Credentials.Otp')"
                Start-Sleep -Seconds 10
            } Until ($Count -lt 30 -and $Global:Config.'Credentials.Otp' -ne '111111')
        } Catch {
            Write-Error -Message "$($_.Exception.Message)"
            Throw 'OTP was not loaded form disk'
        }

        If ($Global:Config.'Credentials.Otp' -eq '111111'){
            Write-Error -Message 'No OTP token provided'
            Throw 'No OTP token provided locate your email with the volvo token and run Set-VolvoAuthentication -OtpToken "<OTPcode>" '
        }
        #OTP has been picked up Reset OTP token on disk

        Try{ 
            $OauthToken = Initialize-VolvoAuthenticationTradeOtpForOauth -AuthReturnObject $OtpRequest
        } Catch {
            Write-Error -Message "$($_.Exception.Message)"
            Throw 'Could not trade OTP for Oauth token'
        }
    } 

    Return $OauthToken
}


