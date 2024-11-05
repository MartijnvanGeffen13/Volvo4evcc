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
        [System.Security.SecureString]$Token.AccessToken = Get-Content -Path './AccessToken.txt' | Convertto-SecureString
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

Function Initialize-VolvoAuthentication
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
    If ($Config){
        If (-not($config.'credentials.username')){

            #Force reload attempt from config
            $Config = Import-Clixml -Path "$((Get-Location).path)\volvo4evccconfig.xml" -ErrorAction SilentlyContinue
            
            #Test again on reload
            If (-not($config.'credentials.username')){
                Write-Debug -Message 'Config variable found but no username key present after force reload'
                Throw 'Please run Set-VolvoAuthentication first to configure this module'
            }
        }
    }else{
        If (Test-Path -Path "$((Get-Location).path)\volvo4evccconfig.xml"){
            Write-Debug -Message "$((Get-Location).path)\volvo4evccconfig.xml not found"
            $Config = Import-Clixml -Path "$((Get-Location).path)\volvo4evccconfig.xml"
        }else{
            Write-Debug -Message 'volvo4evccconfig.xml Does not exist'
            Throw 'Please run Set-VolvoAuthentication first to configure this module'
        }        
    }

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
    Write-Debug -Message "Initiate first web auth with claims to $(($Config.'Url.Oauth_Authorise'+$Config.'Url.Oauth_Claims'))"
    $AuthenticationFirstRequestRaw = Invoke-WebRequest -Uri ($Config.'Url.Oauth_Authorise'+$Config.'Url.Oauth_Claims') -Headers $Header -Method 'get' -SessionVariable AuthenticationRawSession
    $AuthenticationFirstRequestJson = $AuthenticationFirstRequestRaw.Content | ConvertFrom-Json
    
    $AuthenticationRawSession

    $AuthenticationFirstRequestJson
}


Function Set-Header
{
<#
	.SYNOPSIS
		Compare 2 headers
	
	.DESCRIPTION
		Compare 2 headers and update the old one with new values or merge
	
	.EXAMPLE
		Set-Header -CurrentHeader $Header -HeaderParameter $config
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