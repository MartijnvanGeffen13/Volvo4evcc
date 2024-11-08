
#Start the web component in a runspace
Start-RestBrokerService

#Initialise first Token or test token on startup
$Token = Confirm-VolvoAuthentication

#loop for timers



#Wrap in loop based on evcc data
$Seconds = 60
do 
{
    If ($Token.ValidTimeToken -lt (Get-date)){
        $Token.Source = 'Invalid-Expired'
        Write-Debug -Message 'Token is expired trying to get new one'

        Try{
            $Token = Get-NewVolvoToken -Token $Token
            Write-Debug -Message 'Token is refreshed succesfully'
        } Catch {
            Write-Error -Message "$($_.Exception.Message)"
            Throw 'Could not get new token'
        }
    }
    #Get EvccData
    $EvccData = Get-EvccData

    If ($True -eq $EvccData.SourceOk){
        If ($true -eq $EvccData.Connected -and $true -eq $EvccData.Charging)
        {
            write-host -Message 'Connected - charging - Fast refresh of volvo SOC data'
            $Seconds = 120
            Watch-VolvoCar -Token $Token
        }
        If ($true -eq $EvccData.Connected -and $false -eq $EvccData.Charging)
        {
            write-host -Message 'Connected - Not charging - Slow refresh of volvo SOC data'
            $Seconds = 300
            Watch-VolvoCar -Token $Token
        }
        If ($false -eq $EvccData.Connected)
        {
            write-host -Message 'Not Connected - No refresh of volvo SOC data'
            $Seconds = 300
            Watch-VolvoCar -Token $Token
        }
        Start-Sleep -Seconds $Seconds
    }else{
        
        Write-Debug -Message 'Evcc data not found or not reachable'
        Start-Sleep -Seconds $Seconds
    }
    
}while ($True) 
