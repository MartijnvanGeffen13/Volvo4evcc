
$Config = @{

'Credentials.Username' = ''
'Credentials.Password' = ''
'Credentials.VccApiKey' = ''
'Url.Oauth_Token' = 'https://volvoid.eu.volvocars.com/as/token.oauth2'
'Url.Oauth_Authorise' = 'https://volvoid.eu.volvocars.com/as/authorization.oauth2'
'Car.Vin' = ''
}

$Config.'Credentials.Username' = Read-Host -AsSecureString -Prompt 'Username'
$Config.'Credentials.Password' = Read-Host -AsSecureString -Prompt 'Password'
$Config.'Credentials.VccApiKey' = Read-Host -AsSecureString -Prompt 'VccApiKey'
$Config.'Car.Vin' = Read-Host -AsSecureString -Prompt 'VIN'

$Header = @{
  
'authorization' = 'Basic aDRZZjBiOlU4WWtTYlZsNnh3c2c1WVFxWmZyZ1ZtSWFEcGhPc3kxUENhVXNpY1F0bzNUUjVrd2FKc2U0QVpkZ2ZJZmNMeXc='
'User-Agent' = 'volvo4evcc'
'lang' ='en'
'country'='us'
'Accept-Encoding' = 'gzip'
'content-type'= 'application/json; charset=utf-8'
}

$UrlParameters = '?client_id=h4Yf0b&response_type=code&acr_values=urn:volvoid:aal:bronze:2sv&response_mode=pi.flow&scope=openid energy:battery_charge_level energy:charging_connection_status energy:charging_system_status energy:electric_range energy:estimated_charging_time energy:recharge_status'

$AuthenticationRequestRaw = Invoke-WebRequest -Uri ($Config.'Url.Oauth_Authorise'+$UrlParameters) -Headers $Header -Method 'get' -SessionVariable AuthenticationRequestRawSession
$AuthenticationRequestJson = $AuthenticationRequestRaw.Content | ConvertFrom-Json


$AuthenticationRequestRawSession.Headers.Add('x-xsrf-header','PingFederate')


$NextUrl = $AuthenticationRequestJson._links.checkUsernamePassword.href + '?action=checkUsernamePassword'

$AuthenticationRequestOtp = Invoke-WebRequest `
-Uri $NextUrl `
-Method 'post' `
-Body (@{
    'username' = $Config.'Credentials.Username' | ConvertFrom-SecureString -AsPlainText
    'password' = $Config.'Credentials.Password' | ConvertFrom-SecureString -AsPlainText
} | ConvertTo-Json) `
-WebSession $AuthenticationRequestRawSession `
-Headers $Header

$AuthenticationRequestOtpJson = $AuthenticationRequestOtp.content | ConvertFrom-Json

$NextUrl =  $AuthenticationRequestOtpJson._links.checkOtp.href + '?action=checkOtp'

$OTP = Read-Host -Prompt 'Enter OTP token'
$BodyOtp = @{'otp'= $OTP} | convertto-json

$AuthenticationRequestSendOtp = Invoke-WebRequest -Uri $NextUrl -Method 'post' -Body $BodyOtp -WebSession $AuthenticationRequestRawSession -Headers $Header


$AuthenticationRequestSendOtpJson = $AuthenticationRequestSendOtp.Content | ConvertFrom-Json

$NextUrl = $AuthenticationRequestSendOtpJson._links.continueAuthentication.href + '?action=continueAuthentication'

$AuthenticationRequestComplete = Invoke-WebRequest -Uri $NextUrl -Method 'get' -WebSession $AuthenticationRequestRawSession -Headers $Header
$AuthenticationRequestCompleteJson = $AuthenticationRequestComplete.content | ConvertFrom-Json

#Get Oauth
$Header.'content-type' = 'application/x-www-form-urlencoded'

$Body = @{
    'code' = $AuthenticationRequestCompleteJson.authorizeResponse.code
    'grant_type' = 'authorization_code'
}


$AuthenticationRequestOauth = Invoke-WebRequest -Uri $Config.'Url.Oauth_Token' -Method 'post' -Body $Body -WebSession $AuthenticationRequestRawSession -Headers $Header


$AuthenticationRequestOauthJson =  $AuthenticationRequestOauth.Content | ConvertFrom-Json

#store
$AccessToken = $AuthenticationRequestOauthJson.access_token |ConvertTo-SecureString -AsPlainText
$RefreshToken = $AuthenticationRequestOauthJson.refresh_token |ConvertTo-SecureString -AsPlainText
$ValidTimeToken = (Get-Date).AddSeconds( $AuthenticationRequestOauthJson.expires_in -120 )

$AccessToken | ConvertFrom-SecureString  | out-file ./AccessToken.txt
$RefreshToken | ConvertFrom-SecureString  | out-file ./RefreshToken.txt
$ValidTimeToken.ToString() | out-file ./ValidTime.txt



#Start of app or loop
$Token = @{}
If (Test-Path -Path './AccessToken.txt') {$Token.AccessToken = Get-Content -Path '.\AccessToken.txt' | Convertto-SecureString | ConvertFrom-SecureString -AsPlainText}
If (Test-Path -Path './RefreshToken.txt'){$Token.RefreshToken = Get-Content -Path '.\RefreshToken.txt' | Convertto-SecureString | ConvertFrom-SecureString -AsPlainText}
If (Test-Path -Path './ValidTime.txt')   {$Token.ValidTimeToken = Get-Content -Path '.\ValidTime.txt' | Get-Date}

$header = @{
    'authorization' = 'Basic aDRZZjBiOlU4WWtTYlZsNnh3c2c1WVFxWmZyZ1ZtSWFEcGhPc3kxUENhVXNpY1F0bzNUUjVrd2FKc2U0QVpkZ2ZJZmNMeXc='
    'content-type' = 'application/x-www-form-urlencoded'
    'accept' = 'application/json'
}

$Body = @{
    'grant_type' = 'refresh_token'
    'refresh_token' = $Token.RefreshToken
}

$Token = @{}
$AuthenticationRefreshToken = Invoke-WebRequest -Body $Body -Uri $Config.'Url.Oauth_Token' -Method 'post' -Headers $Header -WebSession $AuthenticationRequestRawSession
$AuthenticationRefreshTokenJson = $AuthenticationRefreshToken.Content | ConvertFrom-Json

$Token.AccessToken = $AuthenticationRefreshTokenJson.access_token
$Token.RefreshToken = $AuthenticationRefreshTokenJson.refresh_token
$Token.ValidTimeToken = (Get-Date).AddSeconds($AuthenticationRefreshTokenJson.expires_in -120 )

#We have token now or refreshed token

#Get car

$CarData = Invoke-WebRequest `
-Uri ("https://api.volvocars.com/energy/v1/vehicles/$($Config.'Car.Vin' | ConvertFrom-SecureString -AsPlainText)/recharge-status") `
-Method 'get' `
-Headers @{
    'vcc-api-key' = $Config.'Credentials.VccApiKey' | ConvertFrom-SecureString -AsPlainText
    'content-type' = 'application/json'
    'accept' = '*/*'
    'authorization' = ('Bearer ' + $Token.AccessToken)
}

$CarDataJson = ($CarData.RawContent -split '(?:\r?\n){2,}')[1] | convertfrom-json

$CarDataJson