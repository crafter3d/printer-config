# Firmware Flashing and UUID Provisioning Guide

This guide covers firmware download, flashing, and CAN UUID assignment for Crafter 3D M6.

## 1) Download Firmware

Use [latest/manifest.json](latest/manifest.json) as the source of truth for checksums, Klipper ref, and the correct file for each board.

Published artifact names:

- `octopus-f446-usb-can.bin`: Octopus when it is the USB-to-CAN bridge
- `octopus-f446-usb.bin`: Octopus when it is connected directly by USB
- `ebb42-g0b1-can.bin`: EBB42 toolhead board
- `u2c-v21-g0b1-usb-can.bin`: U2C v2.1 bridge
- [Latest downloads directory](latest/)

Always verify checksum and Klipper compatibility from the manifest before flashing.

## 2) Safety Warnings

- Power the printer off before changing BOOT jumpers, connecting or disconnecting CAN wiring, or moving SD cards between boards.
- If you use a dedicated U2C bridge, flash Octopus with `octopus-f446-usb.bin`. Do not use the Octopus bridge build in that topology.
- If you use Octopus as the USB-to-CAN bridge, do not also put a U2C bridge in the same host-to-CAN path.
- For EBB42 USB DFU, unplug the CAN/power harness before connecting USB to avoid powering the board from both the printer and the host.

## 3) Flash Firmware

### Octopus (USB-to-CAN bridge mode, SD card)

1. Copy `octopus-f446-usb-can.bin` to an SD card.
2. Rename it to `firmware.bin`.
3. Insert SD card into Octopus.
4. Power cycle the printer board.
5. Wait for flash completion (board typically renames file after successful update).

### Octopus (plain USB mode, SD card)

1. Copy `octopus-f446-usb.bin` to an SD card.
2. Rename it to `firmware.bin`.
3. Insert SD card into Octopus.
4. Power cycle the printer board.
5. Wait for flash completion.

### EBB42 (STM32CubeProgrammer)

1. Put EBB42 into USB DFU mode.
2. Open STM32CubeProgrammer and connect to the USB DFU target.
3. Select the EBB42 `.bin` file.
4. Use flash start address `0x08000000`.
5. Flash and verify.
6. Exit DFU mode and power cycle.

### U2C v2.1 (microSD card)

1. Download `u2c-v21-g0b1-usb-can.bin`.
2. Rename it to `firmware.bin`.
3. Copy it to the root of the U2C microSD card.
4. Insert the card into the U2C v2.1.
5. Power cycle or reset the adapter.
6. Wait for the flash to complete before removing the card.

## 4) Assign CAN UUIDs (Primary Method: Mainsail)

1. Open Mainsail.
2. Go to `Machine -> Devices -> CAN`.
3. Refresh and collect unassigned UUIDs.
4. If board mapping is unclear, disconnect/reconnect EBB42 and refresh again.
5. Update `local/mcus.cfg` with:

```ini
[mcu]
serial: /dev/serial/by-id/usb-Klipper_stm32f446xx_<unique-id>

[mcu toolhead]
canbus_uuid=<ebb42_uuid>
canbus_interface: can0
```

6. Do not add a separate `[mcu]` section for U2C. It is only the CAN interface provider.
7. Restart Klipper.

If Octopus itself is the USB-to-CAN bridge, use `canbus_uuid` for both MCUs instead of `serial` plus `canbus_interface`.

## 5) CLI Fallback (when UI is unavailable)

```bash
~/klippy-env/bin/python ~/klipper/scripts/canbus_query.py can0
```

Use the same board identification logic (disconnect/reconnect EBB42 if needed),
then write values into `local/mcus.cfg`.

## 6) Post-Flash Validation

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
