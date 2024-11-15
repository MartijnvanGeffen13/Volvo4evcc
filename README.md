# Volvo4evcc

This addon for EVCC will provide the interface between the volvo API and EVCC. It supports the 2FA Auth flow and does not need a MQTT broker. This module is build as a dedicated EVCC module. 

You can also try a a full feature set build for Home assistend via the Volvo2MQTT addon but it has some drawbacks if used for EVCC. That is why this addon was build to improve on those challanges.

Currently we are in Release state of Rc2. this versions seems to run stable , documentation is on its way in the wiki with roughly 80% done

Current State:
- First Release candidate RC2 is in the main branch release and running stable in production now for over 48 Hours now (Linux host) 

Features in current RC2 release module: (See wiki for instalation instructions 80% done)

- Car status should be auto detectable by EVCC
- Support for Volvo 2FA authentication
- No Constant live poll Only poll when connected and charging. Update poll intervall based on connection and SOC (high interval when charging, low interval when connected but not charging, super low interval when not connected)
- Only pull data interresting for EVCC from API to increase security
- Request minimal Oauth scope in auth session to improve security
- Handle all credentials encrypted at all times
- Application is Multi threaded to increase flexability 
- Volvo4Evcc is using a super light weight web instance to host the JSON response meaning no MQTT or extra broker is needed.
- Direct EVCC Yaml intergration
- Auto application restarts and startup via crontab no matter if app is started allready

Instalation prerequisits:
https://github.com/MartijnvanGeffen13/Volvo4evcc/wiki/0-Installation-Prerequisites

Installation instructions of the module
https://github.com/MartijnvanGeffen13/Volvo4evcc/wiki/1-Installation-of-Volvo4Evcc

EVCC Yaml Code:
https://github.com/MartijnvanGeffen13/Volvo4evcc/wiki/2-EVCC-Yaml-Code


Roadmap Items:

- Implement improved solar charning by detecting SOC and set modes (PV,minPV) based on the SOC state.
  
![alt text](./Images/cars.jpg)  

![alt text](./Images/1.png)

![alt text](./Images/2.png)
