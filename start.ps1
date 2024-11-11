#Start the web component in a runspace
Start-RestBrokerService

#Initialise first Token or test token on startup
$Token = Confirm-VolvoAuthentication

Start-Volvo4Evcc -debug