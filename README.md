# Headset Readiness Check

A read-only Windows tool from Esprit ICT that helps assess a laptop for a
Microsoft Teams headset connected directly through Bluetooth Classic or
Bluetooth LE Audio. Built by **Ronald Magendans** and **Erwin Bierens**.

The tool reports individual checks and explains what still needs to be verified.
It does **not** certify a laptop, headset, connection, or Teams call. Microsoft
certification depends on the exact headset model and how it is connected.

## What it checks

- Windows version and build, including the Windows 11 22H2 baseline for LE Audio.
- Presence of a Bluetooth controller, plus available radio properties.
- Installed Bluetooth, Wi-Fi, audio and Intel Smart Sound Technology drivers.
- The installed Teams desktop package version for the current user, when available.
- Bluetooth and audio devices and relevant Windows services.

Choose **Native Bluetooth Classic** or **Bluetooth LE Audio** before scanning.
Each `OK` applies only to its own check. `Handmatig` and `Onbekend` mean that
the condition has not been established. `Advies` is a recommendation;
`Probleem` identifies a detected blocker.

## Checks you must complete yourself

1. Confirm that the laptop has an integrated Bluetooth radio. An internal
   radio can appear on a USB bus, so the bus name alone is not decisive.
2. For LE Audio, open **Settings > Bluetooth & devices > Devices** and check
   that **Use LE Audio when available** is present and on. Confirm LE Audio or
   TMAP support for the exact headset model.
3. Find the exact headset variant in the appropriate [Microsoft certified
   peripherals list](https://learn.microsoft.com/en-us/microsoftteams/devices/usb-devices).
   USB, native Bluetooth Classic and native Bluetooth LE Audio are distinct
   connection scenarios.
4. Pair the headset directly with Windows, select its speaker and microphone
   in the Teams desktop client, and make a test call. Check audio, microphone,
   mute synchronization, call controls and the Teams button where applicable.

The current version does not automatically read the LE Audio switch, identify
the active audio codec, or prove which device Teams selected. It does not
assess the USB-dongle scenario. This is a laptop and connection precheck, not
an end-to-end pass/fail decision for a particular headset.

## Run and build

This project targets **Windows 11**. Build it on Windows with Windows
PowerShell 5.1 and the .NET Framework compiler:

```powershell
powershell.exe -NoProfile -File .\build.ps1
```

The build creates `dist\EspritICTBluetoothCheck.exe`. Launch it, select a
variant, then choose **Controle starten**. The interface is currently in Dutch.
No administrator rights are normally required. The app only reads system
information; it does not change settings or install drivers. The executable
is not digitally signed, so organization policy may prevent it from running.

Run the rule tests with:

```powershell
powershell.exe -NoProfile -File .\tests\Test-Rules.ps1
```

No prebuilt executable is committed to this repository. Build from the source
or use a release whose build and source revision can be verified.

## Privacy

The scan runs locally and does not upload inventory data. An exported report
can contain the computer model, device names, driver details and hardware
identifiers. Review it before sharing it with Esprit ICT or anyone else.
Do not commit real customer reports or browser profiles to this repository.

## Sources and context

- [Erwin's article on Teams-certified headsets](https://erwinbierens.com/teams-certified-headsets-usb-bluetooth-classic-le-audio)
- [Microsoft: native Bluetooth peripherals for Teams](https://learn.microsoft.com/en-us/microsoftteams/devices/bluetooth-devices)
- [Microsoft: check Windows 11 LE Audio support](https://support.microsoft.com/en-us/windows/hardware/bluetooth/check-if-a-windows-11-device-supports-bluetooth-low-energy-audio)
- [Microsoft: LE Audio stereo quality settings](https://support.microsoft.com/en-us/windows/hardware/bluetooth/configuring-bluetooth-le-audio-quality-settings-on-windows-11)

Rules were last reviewed on **23 November 2026**. Recheck Microsoft's
requirements and certified device list when using the tool later.

## License

The application code and documentation are licensed under [MIT](LICENSE).
The Esprit ICT brand assets in `assets/` are excluded from that license; see
[the asset notice](assets/README.md).
