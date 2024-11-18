$Longitude = 5.77
$Latitude = 51.29

$Url1 = "https://api.open-meteo.com/v1/forecast?latitude=$Latitude&longitude=$Longitude&daily=sunshine_duration&forecast_days=16"
$Url2 = "https://api.open-meteo.com/v1/forecast?latitude=$Latitude&longitude=$Longitude&hourly=temperature_2m,precipitation_probability,precipitation,rain,showers,cloud_cover&forecast_days=7"

$Hourly = invoke-RestMethod -Uri $Url2
$Daily = invoke-RestMethod -Uri $Url1


$Forecast = @()
$Counter = 0
foreach ($time in $Hourly.hourly.time)
{
    $TempObject = New-Object -TypeName "PSCustomObject"
    $TempObject | Add-Member -memberType 'noteproperty' -name 'Time' -Value $Hourly.hourly.time[$counter].split(":")[0]
    $TempObject | Add-Member -memberType 'noteproperty' -name 'Temp' -Value $Hourly.hourly.temperature_2m[$counter]
    $TempObject | Add-Member -memberType 'noteproperty' -name 'RainInMm' -Value $Hourly.hourly.precipitation[$Counter]
    $TempObject | Add-Member -memberType 'noteproperty' -name 'Rainchance' -Value $Hourly.hourly.precipitation_probability[$Counter]
    $TempObject | Add-Member -memberType 'noteproperty' -name 'cloudcover' -Value $Hourly.hourly.cloud_cover[$Counter]
    $Counter++
    $Forecast += $TempObject
}


$ForecastDaily = @()
$Counter2 = 0
foreach ($time in $Daily.daily.time)
{
    $TempObject = New-Object -TypeName "PSCustomObject"
    $TempObject | Add-Member -memberType 'noteproperty' -name 'Time' -Value $Daily.daily.time[$counter2]
    $TempObject | Add-Member -memberType 'noteproperty' -name 'SunHours' -Value ($Daily.daily.sunshine_duration[$counter2]/3600)
    $Counter2++
    $ForecastDaily += $TempObject
}


$Evcc = Invoke-RestMethod -Uri 'http://192.168.178.201:7070/api/state' -Method get

$TargetVehicle = $evcc.result.vehicles | Get-Member |  Where-Object -FilterScript {$_.Membertype -eq "NoteProperty" }

#Current limit
$Evcc.result.vehicles.($TargetVehicle.Name).minSoc

$ResultSetNewMinSoc = Invoke-RestMethod -Uri "http://192.168.178.201:7070/api/vehicles/$($TargetVehicle.Name)/minsoc/$NewMinSoc" -Method Post
