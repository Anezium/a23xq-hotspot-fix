#!/system/bin/sh
# The Wi-Fi HAL rejects swlan0 and crashes in setCountryCode; wlan01 is accepted.
resetprop -n ro.vendor.wifi.sap.interface wlan01
