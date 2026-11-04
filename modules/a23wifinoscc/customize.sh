# Built from the phone's own config, so only this one setting changes.
S=/vendor/etc/wifi/WCNSS_qcom_cfg.ini
O=$MODPATH/system/vendor/etc/wifi
[ "$(getprop ro.product.device)" = a23xq ] || abort "! This module is only for the Galaxy A23 5G (a23xq)"
[ -f "$S" ] || abort "! $S not found"
grep -q '^gWlanMccToSccSwitchMode *=' "$S" || abort "! gWlanMccToSccSwitchMode not found in $S"
mkdir -p "$O"
sed 's/^gWlanMccToSccSwitchMode *=.*/gWlanMccToSccSwitchMode = 0/' "$S" > "$O/WCNSS_qcom_cfg.ini"
set_perm "$O/WCNSS_qcom_cfg.ini" 0 0 0644 u:object_r:vendor_configs_file:s0
ui_print "- gWlanMccToSccSwitchMode will be 0 after reboot"
