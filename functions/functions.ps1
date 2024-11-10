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

    [CmdletBinding(DefaultParameterSetName = 'Default')]
    Param (  
        
        [Parameter(Mandatory=$False,
        ParametersetName = 'Default')]
        [String]$OtpToken,

        [Parameter(Mandatory=$False,
        ParametersetName = 'Reset')]
        [switch]$ResetOtpToken

    )
    
    If ($PSBoundParameters.ContainsKey('OtpToken')){
    
        #First reload current config before exporting again could be other default session that was started
        $Global:Config = Import-ConfigVariable -Reload

        $Global:Config.'Credentials.Otp' = $OtpToken
        Write-Debug -Message "Otp token writen to config"
        
        Export-Clixml -InputObject $Global:Config -Path "$((Get-Location).path)\volvo4evccconfig.xml"
        Write-Debug -Message "Exporting config to $((Get-Location).path)\volvo4evccconfig.xml"

    }elseif ($PSBoundParameters.ContainsKey('ResetOtpToken') ) {

        $Global:Config = Import-ConfigVariable -Reload

        $Global:Config.'Credentials.Otp' = '111111'
        Write-Debug -Message "Otp token Reset in config"
        
        Export-Clixml -InputObject $Global:Config -Path "$((Get-Location).path)\volvo4evccconfig.xml"
        Write-Debug -Message "Exporting config to $((Get-Location).path)\volvo4evccconfig.xml"

    }else {

        $Global:Config.'Credentials.Username' = Read-Host -AsSecureString -Prompt 'Username'
        $Global:Config.'Credentials.Password' = Read-Host -AsSecureString -Prompt 'Password'
        $Global:Config.'Credentials.VccApiKey' = Read-Host -AsSecureString -Prompt 'VccApiKey'
        $Global:Config.'Car.Vin' = Read-Host -AsSecureString -Prompt 'VIN'
        $Global:Config.'Url.Evcc' = Read-Host -Prompt 'EVCC URL eg: http://192.168.178.201:7070'
        #Reset OTP on every export
        $Global:Config.'Credentials.Otp' = '111111'
        
        Export-Clixml -InputObject $Global:Config -Path "$((Get-Location).path)\volvo4evccconfig.xml"
        Write-Debug -Message "Exporting config to $((Get-Location).path)\volvo4evccconfig.xml"

        return $Global:Config

    }

}

Function Start-Volvo4Evcc
{
<#
	.SYNOPSIS
		This will start the module interactive
	
	.DESCRIPTION
		This will start the module interactive
	

    .EXAMPLE
        Starts the module interactive

        Start-Volvo4Evcc

#>

    [CmdletBinding(DefaultParameterSetName = 'Default')]
    Param ()

    #Start the web component in a runspace Recycle old runspace if this exist to free up web port
    Reset-VolvoWebService

    #Initialise first Token or test token on startup
    $Token = Confirm-VolvoAuthentication

    #loop for timers

    #Wrap in loop based on evcc data
    $Seconds = 60
    $RunCount = 0
    do 
    {
        #Increase run count
        $RunCount++

        #Check token validity and get new one if near expiration
        If ($Token.ValidTimeToken -lt (Get-date).AddSeconds(-120)){
            $Token.Source = 'Invalid-Expired'
            Write-Debug -Message 'Token is expired trying to get new one'

            Try{
                $Token = Get-NewVolvoToken -Token $Token
                Write-Debug -Message 'Token is refreshed succesfully'
            } Catch {
                Write-Error -Message "$($_.Exception.Message)"
                Throw 'Could not get new token please restart with full auth and 2FA'
            }
        }
        #Get EvccData
        $EvccData = Get-EvccData

        If ($True -eq $EvccData.SourceOk){
            #Get Volvo data 2 times slower than every poll
            If ($true -eq $EvccData.Connected -and $true -eq $EvccData.Charging -and ($RunCount%1) -eq 0){
            
                Write-Host -Message 'Connected - charging - Fast refresh of volvo SOC data'
                Watch-VolvoCar -Token $Token
            }
            #Get Volvo data 5 times slower than every poll
            If ($true -eq $EvccData.Connected -and $false -eq $EvccData.Charging  -and ($RunCount%4) -eq 0){
                #Also cycle web service
                Reset-VolvoWebService
                Write-Host -Message 'Connected - Not charging - Slow refresh of volvo SOC data'
                Watch-VolvoCar -Token $Token
            }
            #Get Volvo data 5 times slower than every poll
            If ($false -eq $EvccData.Connected -and ($RunCount%59) -eq 0){
            
                Write-Host -Message 'Not Connected - No refresh of volvo SOC data'
                Watch-VolvoCar -Token $Token
            }
            #Get Volvo data if this is the first poll
            If ($RunCount -eq 1){
            
                Write-Host -Message "Startup with Connected:$($EvccData.Connected) - Charging:$($EvccData.Charging)"
                Watch-VolvoCar -Token $Token
            }
        }else{
            Write-Host -Message 'Evcc data not found or not reachable'
            Write-Debug -Message 'Evcc data not found or not reachable'
        }
        
        #Sleep till next run
        If (($RunCount%5) -ne 0){
            Write-Host -Message 'Just a Evcc pull and token test no action taken'
        }

        Start-Sleep -Seconds $Seconds
        
    }while ($True) 

}