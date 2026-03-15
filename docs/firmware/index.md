# Firmware Flashing and UUID Provisioning Guide

This guide covers firmware download, flashing, and CAN UUID assignment for Crafter 3D M6.

## 1) Download Firmware

- [Octopus Firmware (.bin)](latest/octopus-f446-usb-can.bin)
- [EBB42 Firmware (.bin)](latest/ebb42-g0b1-can.bin)
- [Manifest (checksums, Klipper ref, metadata)](latest/manifest.json)

Always verify checksum and Klipper compatibility from the manifest before flashing.

## 2) Flash Firmware

### Octopus (normal method: SD card)

1. Copy the downloaded Octopus binary to an SD card.
2. Rename it to `firmware.bin`.
3. Insert SD card into Octopus.
4. Power cycle the printer board.
5. Wait for flash completion (board typically renames file after successful update).

### EBB42 (normal method: STM32CubeProgrammer)

1. Put EBB42 into USB DFU mode.
2. Open STM32CubeProgrammer and connect to the USB DFU target.
3. Select the EBB42 `.bin` file.
4. Use flash start address `0x08000000`.
5. Flash and verify.
6. Exit DFU mode and power cycle.

## 3) Assign CAN UUIDs (Primary Method: Mainsail)

1. Open Mainsail.
2. Go to `Machine -> Devices -> CAN`.
3. Refresh and collect unassigned UUIDs.
4. If board mapping is unclear, disconnect/reconnect EBB42 and refresh again.
5. Update `hardware/mcu.cfg` with:

```ini
[mcu]
canbus_uuid=<octopus_uuid>

[mcu toolhead]
canbus_uuid=<ebb42_uuid>
```

6. Restart Klipper.

## 4) CLI Fallback (when UI is unavailable)

```bash
~/klippy-env/bin/python ~/klipper/scripts/canbus_query.py can0
```

Use the same board identification logic (disconnect/reconnect EBB42 if needed),
then write UUIDs into `hardware/mcu.cfg`.

## 5) Post-Flash Validation

Run:

```bash
grep -E 'mcu|MCU|canbus|error|timeout' ~/printer_data/logs/klippy.log | tail -30
```

Expected result: both MCUs initialize without timeout errors.

## Maintainer Notes

Latest firmware publication is automated by:

- `.github/workflows/publish-firmware.yml`

The workflow builds binaries from a selected `klipper_ref`, updates `latest/`,
archives previous artifacts in `releases/`, and publishes via GitHub Pages.
