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
        Write-LogEntry -Severity 1 -Message 'Access Token Not found on disk'
        $Token.AccessToken = 'Not Found on Disk'
        $Token.Source = 'Invalid'
    }
    If ($Token.AccessToken -ne 'Not Found on Disk'){
        $Token.Source = 'Disk'

        If ($Token.ValidTimeToken -lt (Get-date)){
            $Token.Source = 'Invalid-Expired'
            Write-LogEntry -Severity 2 -Message 'Token is expired'
        }
    }else{
        $Token.Source = 'Invalid'
        Write-LogEntry -Severity 2 -Message 'Passing invalid Token state'
    }    
            
    return $Token
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
        If (-not($Global:Config.'Credentials.RedirectUri')){

            #Force reload attempt from config
            If (Test-Path -Path "$((Get-Location).path)\volvo4evccconfig.xml" ) {
                $Global:Config = Import-Clixml -Path "$((Get-Location).path)\volvo4evccconfig.xml" -ErrorAction SilentlyContinue
            }else{
                Throw 'Please run Set-VolvoAuthentication first to configure this module'
            }
            
            #Test again on reload
            If (-not($Global:Config.'Credentials.RedirectUri') -or -not($Global:Config.'Credentials.ClientId') -or -not($Global:Config.'credentials.ClientSecret') -or -not($Global:Config.'credentials.VccApiKey') -or -not($Global:Config.'Car.Vin')){
                Write-LogEntry -Severity 2 -Message 'Config variable found but no username key present after force reload'
                Throw 'Please run Set-VolvoAuthentication first to configure this module'
            }
        }
    }else{
        If (Test-Path -Path "$((Get-Location).path)\volvo4evccconfig.xml"){
            Write-LogEntry -Severity 1 -Message "$((Get-Location).path)\volvo4evccconfig.xml not found"
            $Global:Config = Import-Clixml -Path "$((Get-Location).path)\volvo4evccconfig.xml"
        }else{
            Write-LogEntry -Severity 1 -Message 'volvo4evccconfig.xml Does not exist'
            Throw 'Please run Set-VolvoAuthentication first to configure this module'
        }        
    }

    return $Global:Config
}

Function Initialize-VolvoAuthenticationTradeOAuthCodeForOauthToken
{
<#
	.SYNOPSIS
		This will take the web session from the OAuthcode, and the OAuthcode URL as input and will trade the OAuthcode for a Oauth token
	
	.DESCRIPTION
		Trade OAuthcode for Oauth token

	.EXAMPLE
		Initialize-VolvoAuthenticationTradeOAuthCodeForOauthToken
#>
    [CmdletBinding()]
    Param (
 
    )

    #Get Oauth
    Write-LogEntry -Severity 2 -Message "Preparing Oauth request"

    #This should be the very first call to the service so we store it in a session variable for automatic handeling of the cookies
    Write-LogEntry -Severity 2 -Message "Attempt to tradeding auth code for token on $($Global:Config.'Url.Oauth_Token')"
    
    Try {
        #Using Curl seen ps invoke webrequest has issues and allways shows invalid code

        $TokenRequest = Invoke-WebRequest `
        -Uri $Global:Config.'Url.Oauth_Token' `
        -Method 'post' `
        -Body @{
            'grant_type' = 'authorization_code'
            'code' = $Global:Config.'Credentials.OAuthCode' | ConvertFrom-SecureString -AsPlainText
            'redirect_uri' = 'https://volvo4evcc.local/oauth/callback'
            'code_verifier' = $Global:Config.'Credentials.Pkce'.CodeVerifier | ConvertFrom-SecureString -AsPlainText
        } `
        -Headers @{
            'content-type' = 'application/x-www-form-urlencoded'
            'authorization' = ('Basic ' + [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes(("$($Global:Config.'Credentials.ClientId' | ConvertFrom-SecureString -AsPlainText):$($Global:Config.'Credentials.ClientSecret' | ConvertFrom-SecureString -AsPlainText)"))))
            'accept' = 'application/json'
            'User-Agent' = "Volvo4evcc/2.0.0"
        } 

    } catch {
        Write-LogEntry -Severity 1 -Message "Failed to authenticate with Oauth token - $($_.Exception.Message)"
        Throw $_.Exception.Message
    }  


    $AuthenticationRequestOauthJson =  $TokenRequest.Content | ConvertFrom-Json

    #store
    $Token = @{}
    $Token.AccessToken = $AuthenticationRequestOauthJson.access_token |ConvertTo-SecureString -AsPlainText
    $Token.RefreshToken = $AuthenticationRequestOauthJson.refresh_token |ConvertTo-SecureString -AsPlainText
    $Token.ValidTimeToken = (Get-Date).AddSeconds( $AuthenticationRequestOauthJson.expires_in -35 )
    $Token.Source = 'Fresh'

    #Export the token to disk
    $Token | Export-Clixml -Path './EncryptedOAuthToken.xml'

    #Remove variables used during oauth request 
    Remove-Variable -Name TokenRequest
    Remove-Variable -Name AuthenticationRequestOauthJson

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
  "batteryChargeLevel": {
    "status": "OK",
    "value": 0.0,
    "unit": "percentage",
    "updatedAt": "Startup"
  },
  "electricRange": {
    "status": "OK",
    "value": 0,
    "unit": "km",
    "updatedAt": "Startup"
  },
  "chargerConnectionStatus": {
    "status": "OK",
    "value": "DISCONNECTED",
    "updatedAt": "Startup"
  },
  "chargingStatus": {
    "status": "OK",
    "value": "IDLE",
    "updatedAt": "Startup"
  },
  "chargingType": {
    "status": "OK",
    "value": "NONE",
    "updatedAt": "Startup"
  },
  "chargerPowerStatus": {
    "status": "OK",
    "value": "NO_POWER_AVAILABLE",
    "updatedAt": "Startup"
  },
  "estimatedChargingTimeToTargetBatteryChargeLevel": {
    "status": "OK",
    "value": 0,
    "unit": "minutes",
    "updatedAt": "Startup"
  },
  "chargingCurrentLimit": {
    "status": "ERROR",
    "code": "NOT_SUPPORTED",
    "message": "Resource is not supported for this vehicle"
  },
  "targetBatteryChargeLevel": {
    "status": "ERROR",
    "code": "ERROR_READING_PROPERTY",
    "message": "Failed to get target battery charge level"
  },
  "chargingPower": {
    "status": "ERROR",
    "code": "NOT_SUPPORTED",
    "message": "Resource is not supported for this vehicle"
  },
  "EvccStatus": {
    "value": "A"
  }
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
            $WebContent =  $Global:MyData.Cardata
            $EncodingWebContent = [System.Text.Encoding]::UTF8.GetBytes($WebContent)
            $Context.Response.OutputStream.Write($EncodingWebContent , 0, $EncodingWebContent.Length)
            $Context.Response.Close()
            Write-Host "." -NoNewLine
        } until ($False)
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
    -Uri ("https://api.volvocars.com/energy/v2/vehicles/$($Global:Config.'Car.Vin' | ConvertFrom-SecureString -AsPlainText)/state") `
    -Method 'get' `
    -Headers @{
        'vcc-api-key' = $Global:Config.'Credentials.VccApiKey' | ConvertFrom-SecureString -AsPlainText
        'accept' = 'application/json'
        'authorization' = ('Bearer ' + ($Token.AccessToken | ConvertFrom-SecureString -AsPlainText))
    }

    $CarDataJson = $CarData.Content | ConvertFrom-Json
    $Global:MyData.CarData = $CarDataJson
#   $CarDataJson = $global:MyData.CarData | ConvertFrom-Json
    If ($CarDataJson.chargerConnectionStatus.Value -eq 'DISCONNECTED'){
 
        $CarDataJson | add-member -Name "EvccStatus" -value ([PSCustomObject]@{'value'='A'})  -MemberType NoteProperty
 
    }elseif ($CarDataJson.chargerConnectionStatus.Value -eq 'CONNECTED'){
        If ($CarDataJson.chargingStatus.Value -eq 'CHARGING'){
            $CarDataJson| add-member -Name "EvccStatus" -value ([PSCustomObject]@{'value'='C'})  -MemberType NoteProperty
 
        }else{ 
            $CarDataJson| add-member -Name "EvccStatus" -value ([PSCustomObject]@{'value'='B'})  -MemberType NoteProperty
        }
    }elseIf ($CarDataJson.chargerConnectionStatus.Value -eq 'FAULT'){
    
        $CarDataJson| add-member -Name "EvccStatus" -value ([PSCustomObject]@{'value'='B'})  -MemberType NoteProperty
    }

    If ($true -eq $Global:config.'Weather.Enabled'){
        $CarDataJson| add-member -Name "SunHoursTotalAverage" -value ([PSCustomObject]@{'value'= "$($Global:Config.'Weather.SunHoursTotalAverage')"})  -MemberType NoteProperty
        $CarDataJson| add-member -Name "SunHoursToday" -value ([PSCustomObject]@{'value'= "$($Global:Config.'Weather.SunHoursToday')"})  -MemberType NoteProperty
    }
   
    $Global:MyData.CarData = $CarDataJson | ConvertTo-Json
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

    Try {

        #Using Curl seen ps invoke webrequest has issues and allways shows invalid code
 
        $TokenRequest = Invoke-WebRequest `
        -Uri $Global:Config.'Url.Oauth_Token' `
        -Method 'post' `
        -Body @{
            'grant_type' = 'refresh_token'
            'refresh_token' = $Token.RefreshToken | ConvertFrom-SecureString -AsPlainText
            'redirect_uri' = 'https://volvo4evcc.local/oauth/callback'
            'code_verifier' = $Global:Config.'Credentials.Pkce'.CodeVerifier | ConvertFrom-SecureString -AsPlainText
        } `
        -Headers @{
            'content-type' = 'application/x-www-form-urlencoded'
            'authorization' = ('Basic ' + [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes(("$($Global:Config.'Credentials.ClientId' | ConvertFrom-SecureString -AsPlainText):$($Global:Config.'Credentials.ClientSecret' | ConvertFrom-SecureString -AsPlainText)"))))
            'accept' = 'application/json'
            'User-Agent' = "Volvo4evcc/2.0.0"
        } 

        $NewToken = $TokenRequest.Content | ConvertFrom-Json

        $TempToken = @{}
        $TempToken.AccessToken = $NewToken.access_token |ConvertTo-SecureString -AsPlainText
        $TempToken.RefreshToken = $NewToken.refresh_token |ConvertTo-SecureString -AsPlainText
        $TempToken.ValidTimeToken = (Get-Date).AddSeconds( $NewToken.expires_in -35 )
        $TempToken.Source = 'Fresh'

        $TempToken | Export-Clixml -Path './EncryptedOAuthToken.xml'

    } Catch {
    
        Write-LogEntry -Severity 1 -Message $ErrorMessage.ErrorDetails.Message
        $ErrorMessage = $_
        $Token.Source = 'Invalid-Expired'
        Return $Token
    }    
    Remove-Variable -Name NewToken
    Remove-Variable -Name TokenRequest

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
        Write-LogEntry -Severity 0 -Message "$($_.Exception.Message)"
        Throw 'No token found on disk'
    }

    Try{
        $Global:Config = Import-ConfigVariable
    } Catch {
        Write-LogEntry -Severity 0 -Message "$($_.Exception.Message)"
        Throw 'Could not load config'
    }
    

    If ($OauthToken.Source -eq 'Disk'){
        Write-LogEntry -Severity 0 -Message 'Token loaded from Disk succesfull'
        Return $OauthToken
    }

    #Retest if expired needs full auth flow due to test issue last time
    If ($OauthToken.Source -eq 'Invalid' -or $OauthToken.Source -eq 'Invalid-Expired'){
        Write-LogEntry -Severity 2 -Message 'Token Cache issue need to refresh full token'
        Try{
            #Reset disk token to make sure its default
            Set-VolvoAuthentication -ResetOAuthCode
            Initialize-VolvoAuthenticationOauthUserConsent
        } Catch {
            Write-Error -Message "$($_.Exception.Message)"
            Throw 'OOauth code Request failed'
        }
        
        Write-LogEntry -Severity 0 -Message 'login to the browser and catch the oauth code. Update the xml or run Set-VolvoAuthentication -OAuthCode "<OAuthCode>"'

        try{
            $Count = 0
            Do {
                $Count++
                Write-LogEntry -Severity 0 -Message "Running wait for OAuthCode loop $Count of 30"
                $Global:Config = Import-ConfigVariable -Reload
                Write-LogEntry -Severity 2 -Message  "Current OAuthCode value: $($Global:Config.'Credentials.OAuthCode')"
                Start-Sleep -Seconds 2
            } Until ($Count -gt 30 -or $Global:Config.'Credentials.OAuthCode' -ne '111111')
        } Catch {
            Write-Error -Message "$($_.Exception.Message)"
            Throw 'OAuthCode was not loaded form disk'
        }


        If ($Global:Config.'Credentials.OAuthCode' -eq '111111'){
            Write-Error -Message 'No OAuthCode token provided'
            Throw 'No OAuthCode provided please login in the browser and catch the oauth code, then and run Set-VolvoAuthentication -OAuthCode "<OAuthCode>" '
        }
        
        #Convert to secure string 
        $Global:Config.'Credentials.OAuthCode' = $Global:Config.'Credentials.OAuthCode' | ConvertTo-SecureString -AsPlainText
       
        #OAuthCode has been picked up write current config to disk
        Export-Clixml -InputObject $Global:Config -Path "$((Get-Location).path)\volvo4evccconfig.xml"

        Try{ 
            
            $OauthToken = Initialize-VolvoAuthenticationTradeOAuthCodeForOauthToken
        } Catch {
            Write-Error -Message "$($_.Exception.Message)"
            Throw 'Could not get / trade OAuthCode for Oauth token'
        }
    } 

    Return $OauthToken
}

Function Write-LogEntry
{
<#
	.SYNOPSIS
		Write a entry in the log
	
	.DESCRIPTION
		Write a entry in the log based on the severity level of the message
	
	.EXAMPLE
		Write-LogEntry
#>

    [CmdletBinding()]
    Param (  
    
    [Parameter(Mandatory=$True)]
    [String]$Message,

    [Parameter(Mandatory=$False)]
    [Int32]$Severity=0
    )
    

    #Information
    If ($Severity -eq 0){
        If ($Global:Config.'Log.Level' -ge 0){
            "$(Get-Date -Format "yyyyMMdd-HHmm ")Info: $Message" | Out-File -Append -FilePath ./volvo4evcc.log
            
        }
        Write-Host -Message $Message
    }

    #Warning
    If ($Severity -eq 1){
        If ($Global:Config.'Log.Level' -ge 1){
            "$(Get-Date -Format "yyyyMMdd-HHmm ")Warning: $Message" | Out-File -Append -FilePath ./volvo4evcc.log
            
        }
        Write-Warning -Message $Message
    }

    #Debug
    If ($Severity -eq 2){
        If ($Global:Config.'Log.Level' -ge 2){
            "$(Get-Date -Format "yyyyMMdd-HHmm ")Debug: $Message" | Out-File -Append -FilePath ./volvo4evcc.log
            
        }
        Write-Debug -Message $Message   
    }
}

Function Get-SunHours
{
<#
	.SYNOPSIS
		Get the sun hours for the comming days
	
	.DESCRIPTION
		Get the sun hours for the comming days where the sun is delivering PV 
	
	.EXAMPLE
		Get-SunHours
#>

    [CmdletBinding()]
    Param ()
    $Api = "https://api.open-meteo.com/v1/forecast?latitude=$($Global:Config.'Weather.latitude'| ConvertFrom-SecureString -AsPlainText)&longitude=$($Global:Config.'Weather.longitude'| ConvertFrom-SecureString -AsPlainText)&daily=sunshine_duration&forecast_days=16"
    $Daily = Invoke-RestMethod -Uri $Api -Method 'get'

    $ForecastDaily = @()
    $Counter = 0
    foreach ($Time in $Daily.daily.time)
    {
        $TempObject = New-Object -TypeName "PSCustomObject"
        $TempObject | Add-Member -memberType 'noteproperty' -name 'Time' -Value $Daily.daily.time[$counter]
        $TempObject | Add-Member -memberType 'noteproperty' -name 'SunHours' -Value ([math]::Round($Daily.daily.sunshine_duration[$counter]/3600, 1))
        $Counter++
        $ForecastDaily += $TempObject
    }

    Return $ForecastDaily
}


Function Update-SunHours
{
    <#
	.SYNOPSIS
		Update the sun hours for the comming days
	
	.DESCRIPTION
		Update the sun hours for the comming days where the sun is delivering PV 
	
	.EXAMPLE
		Update-SunHours
#>

    [CmdletBinding()]
    Param ()

    Write-LogEntry -Severity 0 -Message 'Weather - Testing weather settings'

    $Sunhours = Get-Sunhours

    $Evcc = Invoke-RestMethod -Uri "$($Global:Config.'Url.Evcc')/api/state" -Method get
    $TargetVehicle = $evcc.result.vehicles | Get-Member |  Where-Object -FilterScript {$_.Membertype -eq "NoteProperty" }

    if($SunHours){
        $SunHours.SunHours[0..($Global:Config.'Weather.SunHoursDaysDevider'-1)] | ForEach-Object -Begin {$TotalSunHours = 0} -Process {$TotalSunHours += $_}
        If (($TotalSunHours / $Global:Config.'Weather.SunHoursDaysDevider') -ge $Global:Config.'Weather.SunHoursHigh'){
            Write-LogEntry -Severity 0 -Message "Weather - More than enough sun"
            
            $ResultSetNewMinSoc = Invoke-RestMethod -Uri "$($Global:Config.'Url.Evcc')/api/vehicles/$($TargetVehicle.Name)/minsoc/$($Global:Config.'Weather.SunHoursMinsocLow')" -Method Post

        }elseIf (($TotalSunHours / $Global:Config.'Weather.SunHoursDaysDevider') -ge $Global:Config.'Weather.SunHoursMedium'){
            Write-LogEntry -Severity 0 -Message "Weather - Medium sun"
            
            #Overwrite the 3 day forecast if today is verry sunny
            If ($SunHours.SunHours[0] -gt $Global:Config.'Weather.SunHoursMedium')
            {
                $MinSocValue = $Global:Config.'Weather.SunHoursMinsocLow'
                Write-LogEntry -Severity 0 -Message "Weather - Daily overwrite As today has more sun"
            }else {
                $MinSocValue = $Global:Config.'Weather.SunHoursMinsocMedium'
            }

            $ResultSetNewMinSoc = Invoke-RestMethod -Uri "$($Global:Config.'Url.Evcc')/api/vehicles/$($TargetVehicle.Name)/minsoc/$MinSocValue" -Method Post

        }elseif(($TotalSunHours / $Global:Config.'Weather.SunHoursDaysDevider') -lt $Global:Config.'Weather.SunHoursMedium'){
            Write-LogEntry -Severity 0 -Message "Weather - Not enough sun"
            
            #Overwrite the 3 day forecast if today is verry sunny
            If ($SunHours.SunHours[0] -gt $Global:Config.'Weather.SunHoursMedium')
            {
                $MinSocValue = $Global:Config.'Weather.SunHoursMinsocLow'
                Write-LogEntry -Severity 0 -Message "Weather - Daily overwrite As today has more sun"
            }else {
                $MinSocValue = $Global:Config.'Weather.SunHoursMinsocHigh'
            }

            $ResultSetNewMinSoc = Invoke-RestMethod -Uri "$($Global:Config.'Url.Evcc')/api/vehicles/$($TargetVehicle.Name)/minsoc/$MinSocValue" -Method Post

        }
    }

    $Global:Config.'Weather.SunHoursTotalAverage' = $TotalSunHours / 3
    $Global:Config.'Weather.SunHoursToday' = $SunHours.SunHours[0]
    
}

Function New-PKCE {
    <#
    .SYNOPSIS
    Generate OAuth 2.0 Proof Key for Code Exchange (PKCE) 'code_challenge' and 'code_verifier' for use with an OAuth2 Authorization Code Grant flow 

    .DESCRIPTION
    Proof Key for Code Exchange (PKCE) is a mechanism, typically used together with an OAuth2 Authorization Code Grant flow to provide an enhanced level of security when authenticating to an Identity Provider (IDP) to get an access token.

    .EXAMPLE 
    Generate the code challenge for a specific code verifier
    New-PKCE -codeVerifier 'yfQ3wNRAyimC2qFc0wXI04u6pb2vRWRfUGdbcILFYOxqC1iJ84dSU0uCsVsHoMuv4Mbu5kmQxd3sZspfnPotrIPx1A9DOVmY3ahcKTjJ5xoGz95A7J8zSw86HW5eZpE'

    .EXAMPLE
    Specify the length of the code verifier to generate
    New-PKCE -length 99

    #>

    [cmdletbinding()]
    param(
        [Parameter(Mandatory = $false, ValueFromPipeline = $true)]
        [int]$length = 43
    )

    $pkceTemplate = [pscustomobject][ordered]@{  
        CodeVerifier  = $null  
        CodeChallenge = $null   
    }  
        

    # From the ASCII Table in Decimal A-Z a-z 0-9
    $codeVerifier = -join (((48..57) * 4) + ((65..90) * 4) + ((97..122) * 4) | Get-Random -Count $length | ForEach-Object { [char]$_ })

    $hashAlgo = [System.Security.Cryptography.HashAlgorithm]::Create('sha256')
    $hash = $hashAlgo.ComputeHash([System.Text.Encoding]::UTF8.GetBytes($codeVerifier))
    $b64Hash = [System.Convert]::ToBase64String($hash)
    $code_challenge = $b64Hash.Substring(0, 43)
    
    $code_challenge = $code_challenge.Replace("/","_")
    $code_challenge = $code_challenge.Replace("+","-")
    $code_challenge = $code_challenge.Replace("=","")

    $pkceChallenges = $pkceTemplate.PsObject.Copy()
    $pkceChallenges.CodeChallenge = $code_challenge | ConvertTo-SecureString -AsPlainText
    $pkceChallenges.CodeVerifier = $codeVerifier | ConvertTo-SecureString -AsPlainText

    return $pkceChallenges 
    
}


Function Initialize-VolvoAuthenticationOauthUserConsent
{
<#
	.SYNOPSIS
		Start a new authentication setting validating full authentication
	
	.DESCRIPTION
		Start a new authentication setting validating full authentication
	
	.EXAMPLE
		Initialize-VolvoAuthenticationOauth
#>

    [CmdletBinding()]
    Param (       	
    )

    #Test if we loaded config allready if not load now
    $Global:Config = Import-ConfigVariable
    
    #Generate End user auth and accept URL

    #Generate PKCE code challenge and verifier
    $Global:Config.'Credentials.Pkce' = New-PKCE -length 43

    #Store Pkce to disk
    Export-Clixml -InputObject $Global:Config -Path "$((Get-Location).path)\volvo4evccconfig.xml"

    $CodeChallengeUrlPart = '&code_challenge=' + ($Global:Config.'Credentials.Pkce'.CodeChallenge| ConvertFrom-SecureString -AsPlainText)  + '&code_challenge_method=S256'

    $AuthUrl = $Global:Config.'Url.Oauth_Authorise' + '?redirect_uri=' + ($Global:Config.'Credentials.RedirectUri'| ConvertFrom-SecureString -AsPlainText) + '&scope=' + $Global:Config.'Url.Oauth_V2_scope'

    $Fullurl = $AuthUrl + $CodeChallengeUrlPart + '&client_id=' + ($Global:Config.'Credentials.ClientId'| ConvertFrom-SecureString -AsPlainText) + '&response_type=code'

    Write-LogEntry -Severity 0 -Message "Use a web browser and consent the API use and login at: (For security reasons url is not in log file)"
    Write-Host -ForegroundColor Cyan -Object $Fullurl
    Write-LogEntry -Severity 0 -Message "DO NOT CLOSE THE BROWSER YOU WILL NEED THE RETURN CODE FROM THE BROWSER TO CONTINUE"
    
    #clean up variables used in this function
    Remove-Variable -name AuthUrl
    Remove-Variable -name Fullurl
    Remove-Variable -name CodeChallengeUrlPart
}