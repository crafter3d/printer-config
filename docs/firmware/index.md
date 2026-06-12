# Firmware Flashing and UUID Provisioning Guide

This guide covers firmware download, flashing, and CAN UUID assignment for Crafter 3D M6.

## 1) Download Firmware

Use [latest/manifest.json](latest/manifest.json) as the source of truth for checksums, Klipper ref, and the correct file for each board.

Published artifact names:

- [octopus-f446-usb-can.bin](latest/octopus-f446-usb-can.bin): Octopus when it is the USB-to-CAN bridge
- [octopus-f446-usb.bin](latest/octopus-f446-usb.bin): Octopus when it is connected directly by USB
- [ebb42-g0b1-can.bin](latest/ebb42-g0b1-can.bin): EBB42 toolhead board
- [u2c-v21-g0b1-usb-can.bin](latest/u2c-v21-g0b1-usb-can.bin): fixed external U2C v2.1 bridge firmware
- [Latest downloads directory](latest/)

Always verify checksum and Klipper compatibility from the manifest before flashing.

## 2) Safety Warnings

- Power the printer off before changing BOOT jumpers, connecting or disconnecting CAN wiring, or moving SD cards between boards.
- If you use a dedicated U2C bridge, flash Octopus with `octopus-f446-usb.bin`. Do not use the Octopus bridge build in that topology.
- If you use Octopus as the USB-to-CAN bridge, do not also put a U2C bridge in the same host-to-CAN path.
- For EBB42 USB DFU, unplug the CAN/power harness before connecting USB to avoid powering the board from both the printer and the host.
- For U2C, use the fixed external firmware from Esoterical's guide. Do not use a Klipper-built U2C image.
- Reference docs: [BTT U2C v2.1 guide](https://canbus.esoterical.online/can_adapter/BigTreeTech%20U2C%20v2.1/README.html) and [BTT EBB42 V1.2 guide](https://canbus.esoterical.online/toolhead_flashing/common_hardware/BigTreeTech%20EBB42%20V1.2/README.html).

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

### EBB42 (USB DFU with dfu-util)

1. Disconnect EBB42 from the printer-side CAN and 24V harness.
2. Add the USB power jumper, then connect EBB42 to the Pi with USB.
3. Hold `RESET` and `BOOT`, release `RESET`, then release `BOOT`.
4. Confirm DFU mode:

```bash
lsusb
sudo dfu-util -l
```

Expected USB ID is `0483:df11` for `STMicroelectronics STM Device in DFU Mode`.

5. Flash the EBB42 firmware:

```bash
sudo dfu-util -D ./ebb42-g0b1-can.bin -a 0 -s 0x08000000:mass-erase:force
```

6. Unplug USB, remove the USB power jumper, reconnect the CAN/power harness, and power cycle the printer.

Reference: [Esoterical BTT EBB42 V1.2 guide](https://canbus.esoterical.online/toolhead_flashing/common_hardware/BigTreeTech%20EBB42%20V1.2/README.html).

### U2C v2.1 (USB DFU with dfu-util)

1. Disconnect CAN wiring from the U2C and connect only USB to the Pi.
2. Hold the U2C `BOOT` button while plugging it into USB.
3. Confirm DFU mode:

```bash
lsusb
sudo dfu-util -l
```

Expected USB ID is `0483:df11` for `STMicroelectronics STM Device in DFU Mode`.

4. Flash the fixed U2C firmware:

```bash
sudo dfu-util -D ./u2c-v21-g0b1-usb-can.bin -a 0 -s 0x08000000:leave
```

5. Ignore `error during download get-status` if the rest of the flash completed successfully.
6. Unplug the U2C, release BOOT/remove any BOOT jumper, plug it back in normally, and verify a CAN interface appears:

```bash
ip -br link
```

Reference: [Esoterical BTT U2C v2.1 guide](https://canbus.esoterical.online/can_adapter/BigTreeTech%20U2C%20v2.1/README.html).

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
downloads the fixed U2C firmware, archives previous artifacts in `releases/`,
and publishes via GitHub Pages.
