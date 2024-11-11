#Start the web component in a runspace
Start-RestBrokerService

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
        If ($true -eq $EvccData.Connected -and $true -eq $EvccData.Charging -and ($RunCount%2) -eq 0){
        
            write-host -Message 'Connected - charging - Fast refresh of volvo SOC data'
            Watch-VolvoCar -Token $Token
        }
        #Get Volvo data 5 times slower than every poll
        If ($true -eq $EvccData.Connected -and $false -eq $EvccData.Charging  -and ($RunCount%5) -eq 0){
        
            write-host -Message 'Connected - Not charging - Slow refresh of volvo SOC data'
            Watch-VolvoCar -Token $Token
        }
        #Get Volvo data 5 times slower than every poll
        If ($false -eq $EvccData.Connected -and ($RunCount%60) -eq 0){
        
            write-host -Message 'Not Connected - No refresh of volvo SOC data'
            Watch-VolvoCar -Token $Token
        }

    }else{
        
        Write-Debug -Message 'Evcc data not found or not reachable'
    }
    
    #Sleep till next run
    Start-Sleep -Seconds $Seconds
    
}while ($True) 








