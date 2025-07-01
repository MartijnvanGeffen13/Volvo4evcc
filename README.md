<h1># Volvo4evcc</h1>

<h3>If you like this project please sponsor me via https://buymeacoffee.com/scriptkiddie</h3>

This addon for EVCC will provide the interface between the volvo API and EVCC. It supports the New modern client OAuth flow and Energy V2 API of volvo. It does not need a MQTT broker. This module is build as a dedicated EVCC module in contrast tot other addons (That are native to Home assistend). This addon is build to improve on the issues other HA based addons have. As a bonus we have added Weather functionality to controle SOC minimum charge state on 3 day weater forecast and greatly enhanced security. 


Currently we are in Release state of Version 2.1.1 this versions seems to run stable , documentation is updated in the wiki. (Please read if you migrate from pre 2.0)

<h3>Current State:</h3>

- V2.1.1 Release
- Complete redesign of OAuth no longer relaying on OTP but true Oauth client flow as per VOLVO documentation. (No more faking the client)
- Move to V2 API now that V1 is depricated

- Issues: no support for multi car , you need 2 instances of the addon 
----

- V1.5 released in the main branch and running stable in production now for over 10 days (Linux host)
=======
Currently we are in Release state of Version 1.8.1 for the single car support.  See other branch for multiple car support. this versions seems to run stable , documentation is in the wiki. 

<h3>Current State:</h3>
- V1.8.1 released in the main branch and running stable in production now for over 50 days (Linux host)

- Weather Module addon available and guide is in the wiki

<h3>Features in current RC3 release module: (See wiki for instalation instructions done)</h3>

- ** Car status is auto detectable by EVCC
- ** Multi car / charger branch to support multiple volvo vehicles and chargers and still working with auto dectect. ( If you need this use the multiple car branch version 1.10.1)
- ** No Constant live poll Only poll when connected and charging. Update poll intervall based on connection and SOC (high interval when charging, low interval when connected but not charging, super low interval when not connected)
- ** Only pull data interresting for EVCC from API to increase security (Not exposing coordinates and door unlock to possible hackers) 
- ** Request minimal Oauth scope in auth session to improve security (Token does not include unlock or coordinate permissions)
- ** Handle all credentials encrypted at all times
- ** Volvo4Evcc is using a super light weight web instance to host the JSON response meaning no MQTT or extra broker is needed.
- ** Reduction in 80% of API traffic VS Volvo2MQTT, Meaning less traffic to your car and battery drain
- ** Application is Multi threaded to increase flexability 
- ** Auto application restarts and startup via crontab no matter if app is started allready
- Support for Volvo 2FA authentication
- Direct EVCC Yaml intergration

**Improvement over Volvo2MQTT

<h3>Added Features:</h3>
- Weather forecast support to auto set the MINSOC charging value based on solar hours for the next 3 days so you dont have to update your plan manual. It will increase when low sun and decrease when sun forcasting is good. Always keeps a buffer for unforcasted sun. 


<h3>If you like this project please sponsor me via https://buymeacoffee.com/scriptkiddie</h3>


<h2>Wiki Items</h2>
Instalation prerequisits:
https://github.com/MartijnvanGeffen13/Volvo4evcc/wiki/0-Installation-Prerequisites

Installation instructions of the module
https://github.com/MartijnvanGeffen13/Volvo4evcc/wiki/1-Installation-of-Volvo4Evcc

EVCC Yaml Code:
https://github.com/MartijnvanGeffen13/Volvo4evcc/wiki/2-EVCC-Yaml-Code

Wheater Module:
https://github.com/MartijnvanGeffen13/Volvo4evcc/wiki/3-Weather-Module

Roadmap Items:

- Implement improved solar charning by detecting SOC and set modes (PV,minPV) based on the SOC state.
- Multi volvo car support
  
![alt text](./Images/cars.jpg)  

![image](https://github.com/user-attachments/assets/f8f8b043-9bd8-4279-8e59-58b25cf17ecf)

![alt text](./Images/2.png)
