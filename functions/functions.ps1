Function Set-VolvoAuthentication
{
<#
	.SYNOPSIS
		Configure the secure credentials used by the module. Store this data encrypted on disk for later use
	
	.DESCRIPTION
		Configure the secure credentials used by the module. Store this data encrypted on disk for later use
        in the file called volvo4evccconfig.xml.  This data can only be loaded by the same user profile that 
        create the encrypted file.
	
	.EXAMPLE
        Run full authentication configuration and store credentials encrypted

		Set-VolvoAuthentication

    .EXAMPLE
        Set the OTP respons to the config

        Set-VolvoAuthentication -OtpToken '123456'

#>

    [CmdletBinding()]
    Param (  
        
        [Parameter(Mandatory=$False)]
        [String]$OtpToken

    )
    
    If ($PSBoundParameters.ContainsKey('OtpToken')){
    
        #First reload current config before exporting again could be other default session that was started
        $Global:Config = Import-ConfigVariable -Reload

        $Config.'Credentials.Otp' = $OtpToken
        Write-Debug -Message "Otp token writen to config"
        
        Export-Clixml -InputObject $Config -Path "$((Get-Location).path)\volvo4evccconfig.xml"
        Write-Debug -Message "Exporting config to $((Get-Location).path)\volvo4evccconfig.xml"

    }else {

        $Config.'Credentials.Username' = Read-Host -AsSecureString -Prompt 'Username'
        $Config.'Credentials.Password' = Read-Host -AsSecureString -Prompt 'Password'
        $Config.'Credentials.VccApiKey' = Read-Host -AsSecureString -Prompt 'VccApiKey'
        $Config.'Car.Vin' = Read-Host -AsSecureString -Prompt 'VIN'
        #Reset OTP on every export
        $Config.'Credentials.Otp' = '111111'
        
        Export-Clixml -InputObject $Config -Path "$((Get-Location).path)\volvo4evccconfig.xml"
        Write-Debug -Message "Exporting config to $((Get-Location).path)\volvo4evccconfig.xml"

        return $Config

    }

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


    $OauthToken = Load-TokenFromDisk

    If ($OauthToken.Source -eq 'Disk'){
        Write-Debug -Message 'Token loaded from Disk succesfull'
        Return $OauthToken
    }

    If ($OauthToken.Source -eq 'Invalid'){
        Write-Debug -Message 'Token Cache issue need to refresh full token'
        $OtpRequest = Initialize-VolvoAuthenticationOtpRequest
        
        Write-Host -ForegroundColor Yellow 'locate your email with the volvo token and run Set-VolvoAuthentication -OtpToken "<OTPcode>"'

        $Count =1
        Do {
            
            $Global:Config = Import-ConfigVariable -Reload
            Write-Host "Running wait for OTP loop $Count of 30"
            $Count++
            Start-Sleep -Seconds 10
        } Until ($count -lt 30 -and $Config.'Credentials.Otp' -ne '111111')

        If ($Config.'Credentials.Otp' -eq '111111'){
            Write-Error -Message 'No OTP token provided'
            Throw 'No OTP token provided locate your email with the volvo token and run Set-VolvoAuthentication -OtpToken "<OTPcode>" '
        }
        #OTP has been picked up proceed

    } 

    If ($OauthToken.Source -eq 'Invalid-Expired'){
        Write-Debug -Message 'Token load successfull but expired need new Access token'
        

        #continue to renew refresh token token
    } 

    Return $OauthToken
}