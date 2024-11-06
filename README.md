# Volvo4evcc

This addon for EVCC will provide the interface between the volvo API and EVCC. It supports the 2FA Auth flow and does not need a MQTT broker. This module is build as a dedicated EVCC module. 

You can also try a a full feature set build for Home assistend via the Volvo2MQTT addon but it has some drawbacks if used for EVCC. That is why this addon was build to improve on those challanges.

Currently we are in a Minimal viable product state meaning we have some raw working code that is not ready for production. 


Feature that should be done before we release a working state module:

- Car status should be auto detected by EVCC
- No Constant live poll Only poll when connected and charging 
- Only pull data usable by EVCC from API instead of everything  **
- Request less scope in auth session to improve security drastically **
- Fix all handling of insecure credential use **
- Multi threaded flows **
- No secondairy Broker like MQTT **
- Direct EVCC Yaml intergration without mqtt  **


** are already in the MVP test.