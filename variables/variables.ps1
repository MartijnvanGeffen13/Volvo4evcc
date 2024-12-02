$Global:Config = @{

    'Credentials.Username' = ''
    'Credentials.Password' = ''
    'Credentials.VccApiKey' = ''
    'Credentials.Otp' = '111111'
    'Car.Vin' = ''
    'Car.Names' = ''
    'Url.Oauth_Token' = 'https://volvoid.eu.volvocars.com/as/token.oauth2'
    'Url.Oauth_Authorise' = 'https://volvoid.eu.volvocars.com/as/authorization.oauth2'
    'Url.Oauth_Claims' = '?client_id=h4Yf0b&response_type=code&acr_values=urn:volvoid:aal:bronze:2sv&response_mode=pi.flow&scope=openid energy:battery_charge_level energy:charging_connection_status energy:charging_system_status energy:electric_range energy:estimated_charging_time energy:recharge_status'
    'Url.Evcc' = 'http://192.168.1.1:7070'
    'Log.Level' = 2
    'Weather.Enabled' = $false
    'Weather.Longitude' = 1
    'Weather.Latitude' = 1
    'Weather.SunHoursHigh' = 7
    'Weather.SunHoursMedium' = 4
    'Weather.SunHoursDaysDevider' = 3
    'Weather.SunHoursTotalAverage' = 0
    'Weather.SunHoursMinsocHigh' = 75
    'Weather.SunHoursMinsocMedium' = 50
    'Weather.SunHoursMinsocLow' = 30
    'Weather.SunHoursToday' = 0
}