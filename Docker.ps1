write-host "Started Docker"

#Test module
if (!(Get-Module DnsClient-PS -ListAvailable)){
    Install-Module -Name DnsClient-PS -force -SkipPublisherCheck -AcceptLicens
}

#Load the module
Import-Module "$($pwd.path)/Volvo4evcc/Volvo4evcc.psd1" 
Import-Module "DnsClient-PS"

Start-Volvo4Evcc