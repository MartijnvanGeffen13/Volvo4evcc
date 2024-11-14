#Load the module
Import-Module "$($pwd.path)/volvo4evcc/Volvo4evcc.psd1" 

#Kill any running process that is the same
If ($PSVersionTable.Platform -like "Unix*"){
    Get-Process 'pwsh' | Where-Object -FilterScript {$_.Commandline -like "*volvo4evcc/start.ps1" -and $_.id -ne $pid } | Stop-Process -Force
}

If ($PSVersionTable.Platform -like "Win*"){
    Get-Process 'pwsh' | Where-Object -FilterScript {$_.Commandline -like "*volvo4evcc/start.ps1" -and $_.id -ne $pid } | Stop-Process -Force
}

Start-Volvo4Evcc
