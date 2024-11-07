
#Start the web component in a runspace
Start-RestBrokerService

#Initialise first Token or test token on startup
$Token = Confirm-VolvoAuthentication

#loop for timers
#Get EvccData
Get-EvccData

#Wrap in loop based on evcc data
Watch-VolvoCar -Token $Token

