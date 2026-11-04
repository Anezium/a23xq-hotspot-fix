# a23xq-hotspot-fix

Magisk modules that fix the Wi-Fi hotspot on the **Samsung Galaxy A23 5G (SM-A236B, `a23xq`)** running [haky86's unofficial LineageOS 22.2](#links).

**[Download the modules](https://github.com/Anezium/a23xq-hotspot-fix/releases/latest)**

This is a community workaround. It is not made or endorsed by haky86, and it has been tested on **one phone** only. See [What has not been tested](#what-has-not-been-tested).

## Which module do I need?

| Module | Fixes | Change |
|---|---|---|
| `a23hotspotfix` | The hotspot fails to start at all | `ro.vendor.wifi.sap.interface=wlan01`, set at every boot |
| `a23wifinoscc` | The hotspot stops after 60 seconds when turned on while Wi-Fi is connected on 5 GHz | `gWlanMccToSccSwitchMode=0` in `WCNSS_qcom_cfg.ini` |

Install both. They are separate so you can remove either one on its own.

The second module does not ship a config file. It builds one at install time from your phone's own `/vendor/etc/wifi/WCNSS_qcom_cfg.ini`, changing that single line.

## Tested on

| | |
|---|---|
| Phone | SM-A236B |
| ROM | `lineage-22.2-20260316-UNOFFICIAL-a23xq`, Android 15, `userdebug` |
| Kernel | `5.4.281-g920d1d7c7904` |
| Stock firmware in the build fingerprint | `A236BXXSDEZA1` |
| Magisk | [v31.1](https://github.com/topjohnwu/Magisk/releases/tag/v31.1) |
| Internet source | Wi-Fi client (no SIM in the phone) |

The hotspot's band setting was 2.4 GHz.

## Install

You need Magisk first. If you do not have it, see [Rooting this ROM with Magisk](#rooting-this-rom-with-magisk).

1. Download both zips from the [latest release](https://github.com/Anezium/a23xq-hotspot-fix/releases/latest).
2. In the Magisk app, open **Modules**, then **Install from storage**, and select the first zip.
3. Do the same for the second zip.
4. Reboot.
5. Turn the hotspot on in Settings.

The modules refuse to install on any device other than `a23xq`.

**To remove a module:** disable or remove it in **Modules**, then reboot.

## What was wrong

### 1. The hotspot does not start

The hotspot fails in under a second, whether Wi-Fi is on or off (3 failures out of 3 before the fix):

1. The system names the hotspot interface `swlan0`, through `ro.vendor.wifi.sap.interface`.
2. The Wi-Fi HAL does not recognise that name: `Unknown iface name: swlan0`.
3. `android.hardware.wifi-service` crashes in `setCountryCode`.
4. The framework loses the interface and logs a misleading error:

   ```
   SoftApManager[swlan0]: failed to set explicitly requested MAC address
   ```

The MAC address is not the cause: the driver accepted the same address when it was set by hand. An overlay disabling MAC randomisation was rejected by Android (`STATE_NO_IDMAP`) and is not needed. `tetherableWifiRegexs` is not blocking either: tethering reached `TetheredState` despite its error message.

Renaming the interface to `wlan01` is enough, with no partition modified:

| | Before | After |
|---|---|---|
| Access point | Fails in under a second | `AP-ENABLED`, SSID broadcast |
| Tethering | None | `TetheredState` |
| Wi-Fi client | Restarts, then drops after repeated failures | Stays connected |

I did not find where `swlan0` is set on this ROM. Another Samsung LineageOS tree, [`lineage-a34x-5g`](https://github.com/potatogeek/lineage-a34x-5g), has the same value in its `vendor.prop`, so it may come from Samsung's stock properties.

### 2. The hotspot stops after 60 seconds

This one only happens if Wi-Fi is already connected on 5 GHz when the hotspot is turned on:

1. The hotspot starts on 2.4 GHz, then moves to the Wi-Fi client's channel (5220 MHz in my test).
2. `hostapd` announces a radar check with `cac_time=60s`, even though this channel does not normally need one.
3. 60 seconds later: `AP-DISABLED`, then `hostapd failure`.

The stock config has `gWlanMccToSccSwitchMode = 3`, which its comment describes as "Force SCC if same band". Setting it to `0` stopped the move in my test.

**How sure is this?** The 60-second cut is measured, and so is its disappearance with this setting. The exact mechanism linking the channel move to the cut is my reading of the logs, not something I proved in the driver.

Without the module, there is a manual workaround: **turn Wi-Fi off, turn the hotspot on, then turn Wi-Fi back on.**

## Test results

| Wi-Fi connected on 5 GHz, then hotspot on | Hotspot frequency | Result |
|---|---|---|
| Without `a23wifinoscc` | Moves to 5220 MHz | **Cut after 60 s, 2 times out of 2**, with or without a device connected |
| With `a23wifinoscc` | Stays on 2.4 GHz (2432 MHz) | **Still on after 7 min 20**, device connected, internet working, no `AP-DISABLED` or `DFS` in the logs |

| Other checks | Result |
|---|---|
| Manual workaround, without `a23wifinoscc` | Still on after 12 min 11, device connected |
| After a reboot, with both modules | Both settings applied, hotspot starts, tethering upstream `wlan0` |
| Wi-Fi client with `a23wifinoscc` | Connected on 5220 MHz, no packet loss to `1.1.1.1` |
| Release zips | Installed through `magisk --install-module`; the resulting script and config are byte-identical to the ones tested above |

## Keep the hotspot on 2.4 GHz

**These modules do not make a 5 GHz hotspot reliable.** With both installed and the Wi-Fi client connected on 5220 MHz, setting **Speed and compatibility** to 5 GHz gave:

| Band setting | Successful starts | Frequency when it started |
|---|---|---|
| 2.4 GHz | 3 out of 3 in a row | 2442 to 2462 MHz |
| 5 GHz | **2 out of 10** | 5765 or 5825 MHz |

Failed 5 GHz starts stop right away, and the hotspot stays off:

```
hostapd: Failed to set beacon parameters
hostapd: Interface initialization failed
hostapd: wlan01: interface state HT_SCAN->DISABLED
SoftApManager[wlan01]: hostapd failure, stop and report failure
```

I did not find the cause, and did not try these starts with Wi-Fi off.

When a 5 GHz start did work, the hotspot stayed on for over 8 minutes on 5765 MHz with a device connected and no 60-second cut. One informal speed test on it gave about 50 Mbps down and 40 Mbps up.

**A lead on the 60-second cut, not a proof:** the phone's regulatory table marks 5220 MHz as `no IR`, so it may not start a network there on its own. 5765 and 5825 MHz do not have that flag, but they are limited to 14 dBm, against 23 dBm for 5220 MHz.

## What has not been tested

- **Other phones:** only one SM-A236B. The ROM itself does not support the other variants (M, E).
- **Other builds:** only the `20260316` build.
- **Mobile data as the internet source:** there was no SIM in the phone. With Wi-Fi off the access point stays up, but sharing mobile data was not tested.
- **Long sessions:** the longest run with both modules on 2.4 GHz is 7 min 20.
- **Speed on 2.4 GHz:** throughput was not properly measured.

## Rooting this ROM with Magisk

**Flashing `boot` can leave your phone unable to start. Back it up first and keep the copy on your PC.**

This is what I did. It needs **Rooted debugging** enabled in Developer options. The Magisk app's **Select and Patch a File** should give the same result, but I did not use it. **Direct Install** is not offered until Magisk itself has root.

On this build, `vbmeta` already has verification disabled (`flags = 3`), and `boot` has a ramdisk, so `boot` is the partition to patch.

1. Back up `boot`:

   ```sh
   adb root
   adb shell dd if=/dev/block/by-name/boot of=/data/local/tmp/boot.img bs=1M
   adb pull /data/local/tmp/boot.img
   ```

2. Install [Magisk v31.1](https://github.com/topjohnwu/Magisk/releases/tag/v31.1). SHA-256 of `Magisk-v31.1.apk`: `89cefac0a318afa39fb3880c45c87b036c05bc1ebf02a7a715b7f8d7c26ac6e7`.

3. Unzip the APK and push these to `/data/local/tmp/mg/`, renamed as shown:

   | From the APK | Name on the phone |
   |---|---|
   | `assets/boot_patch.sh` | `boot_patch.sh` |
   | `assets/util_functions.sh` | `util_functions.sh` |
   | `lib/arm64-v8a/libmagiskboot.so` | `magiskboot` |
   | `lib/arm64-v8a/libmagiskinit.so` | `magiskinit` |
   | `lib/arm64-v8a/libmagisk.so` | `magisk` |
   | `lib/arm64-v8a/libinit-ld.so` | `init-ld` |

4. Patch a copy of `boot`. `Failed to patch` appeared twice in the output here without stopping the patch, and the kernel came out unchanged:

   ```sh
   adb shell
   cd /data/local/tmp/mg
   chmod 755 magiskboot magiskinit magisk init-ld boot_patch.sh
   cp ../boot.img stock.img
   BOOTMODE=true KEEPVERITY=true KEEPFORCEENCRYPT=true PATCHVBMETAFLAG=false RECOVERYMODE=false sh ./boot_patch.sh /data/local/tmp/mg/stock.img
   ```

5. Flash the result, check it, and reboot:

   ```sh
   dd if=new-boot.img of=/dev/block/by-name/boot bs=1M conv=fsync
   dd if=/dev/block/by-name/boot bs=1M | sha256sum
   sha256sum new-boot.img
   reboot
   ```

   The two hashes must match. If they do not, write your backup back before rebooting.

6. Open the Magisk app and accept the additional setup. It reboots once more.

**If the phone does not start:** put `boot.img` in a tar archive and flash it as **AP** in Odin from Download mode. I did not need this, so that path is untested.

`adb root` may need to be run again after each reboot.

## Links

**The ROM**
- [XDA thread: LineageOS 22.2 for the Galaxy A23 5G](https://xdaforums.com/t/rom-15-0-unofficial-dicontinued-sm-a236b-lineageos-22-2-for-samsung-galaxy-a23-5g-ss-ds.4760330/), by haky86
- [`lineage-22.2-20260316-UNOFFICIAL-a23xq.zip`](https://www.mediafire.com/file/zxneye5wha6zwi9/lineage-22.2-20260316-UNOFFICIAL-a23xq.zip/file) and [its recovery](https://www.mediafire.com/file/ecu0gk5xv9ja94b/recovery-22.2-20260316-UNOFFICIAL-a23xq.tar/file)
- [Kernel source at the running commit](https://github.com/Haky86/android_kernel_samsung_sm6375_old/tree/920d1d7c7904)

**Hotspot discussion in that thread**
- [Posts #38 and #39](https://xdaforums.com/t/rom-15-0-unofficial-dicontinued-sm-a236b-lineageos-22-2-for-samsung-galaxy-a23-5g-ss-ds.4760330/page-2): reported as not working, overlays suspected
- [Posts #52, #56 and #58](https://xdaforums.com/t/rom-15-0-unofficial-dicontinued-sm-a236b-lineageos-22-2-for-samsung-galaxy-a23-5g-ss-ds.4760330/page-3): kernel suspected, listed as a known issue

**Related**
- [a23xq-dt2w-fix](https://github.com/Anezium/a23xq-dt2w-fix): double tap to wake for LXS panels on the same ROM
- [Magisk v31.1](https://github.com/topjohnwu/Magisk/releases/tag/v31.1)

## License

[Apache-2.0](LICENSE)
