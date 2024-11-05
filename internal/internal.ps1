Function Update-Configuration
{
<#
	.SYNOPSIS
		Temp Test function to configure config variable
	
	.DESCRIPTION
		Temp Test function to configure config variable
	
	.EXAMPLE
		Update-Configuration
#>

    [CmdletBinding()]
    Param (       	
    )

        $Config.'Credentials.Username' = Read-Host -AsSecureString -Prompt 'Username'
        $Config.'Credentials.Password' = Read-Host -AsSecureString -Prompt 'Password'
        $Config.'Credentials.VccApiKey' = Read-Host -AsSecureString -Prompt 'VccApiKey'
        $Config.'Car.Vin' = Read-Host -AsSecureString -Prompt 'VIN'
            
    return $Config
}