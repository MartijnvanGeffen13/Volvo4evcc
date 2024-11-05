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
		Set-VolvoAuthentication
#>

    [CmdletBinding()]
    Param (       	
    )
    
    $Config.'Credentials.Username' = Read-Host -AsSecureString -Prompt 'Username'
    $Config.'Credentials.Password' = Read-Host -AsSecureString -Prompt 'Password'
    $Config.'Credentials.VccApiKey' = Read-Host -AsSecureString -Prompt 'VccApiKey'
    $Config.'Car.Vin' = Read-Host -AsSecureString -Prompt 'VIN'

    Export-Clixml -InputObject $Config -Path "$((Get-Location).path)\volvo4evccconfig.xml"
    Write-Debug -Message "Exporting config to $((Get-Location).path)\volvo4evccconfig.xml"

    return $Config

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

    If ($OauthToken.Source -like 'Invalid*'){
        Write-Debug -Message 'Token Cache issue need to refresh token'
        $OauthToken = Initialize-VolvoAuthentication
    } 


    Return $OauthToken
}