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
    If (Test-Path -Path './AccessToken.txt') {
        [System.Security.SecureString]$Token.AccessToken = Get-Content -Path './AccessToken.txt' | Convertto-SecureString
    }else {
        $Token.AccessToken = 'Not Found on Disk'
    }
    If (Test-Path -Path './RefreshToken.txt') {
        [System.Security.SecureString]$Token.RefreshToken = Get-Content -Path './RefreshToken.txt' | Convertto-SecureString
    }else {
        $Token.RefreshToken = 'Not Found on Disk'
    }
    If (Test-Path -Path './ValidTime.txt') {
        $Token.ValidTimeToken = Get-Content -Path './ValidTime.txt' | Get-Date
    }else {
        $Token.ValidTimeToken = 'Not Found on Disk'
    }
    
    If ($Token.AccessToken -ne 'Not Found on Disk' -and $Token.RefreshToken -ne 'Not Found on Disk' -and $Token.ValidTimeToken -ne 'Not Found on Disk'){
        $Token.Source = 'Disk'
    }
            
    return $Token
}