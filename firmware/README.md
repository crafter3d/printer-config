# Crafter3D Firmware Profiles and Artifacts

This directory defines the default firmware targets for Crafter 3D M6 setups:

- Main board: BTT Octopus v1.x (STM32F446, USB serial or USB-to-CAN bridge)
- Toolhead board: BTT EBB42 v1.1 (STM32G0B1, CAN)
- USB-to-CAN adapter: BTT U2C v2.1 (STM32G0B1, USB-to-CAN bridge)
- CAN bus speed: 1000000

## Repository Layout

- `profiles/octopus-f446-usb-can.config`: Klipper profile for Octopus when it acts as the USB-to-CAN bridge.
- `profiles/octopus-f446-usb.config`: Klipper profile for Octopus when it connects directly over USB.
- `profiles/ebb42-g0b1-can.config`: Klipper profile for EBB42.
- `profiles/u2c-v21-g0b1-usb-can.config`: Klipper profile for U2C v2.1.
- `octopus-usb-can/firmware.bin`: Local/staging artifact path for Octopus bridge mode.
- `octopus-usb/firmware.bin`: Local/staging artifact path for Octopus USB mode.
- `ebb42/firmware.bin`: Local/staging artifact path for EBB42.
- `u2c-v21/firmware.bin`: Local/staging artifact path for U2C v2.1.
- `../docs/firmware/latest/manifest.json`: Published latest artifact metadata.

## Build Firmware from Profiles

Build on a Pi/host with Klipper source available.

Octopus as USB-to-CAN bridge:

```bash
cd ~/klipper
cp ~/printer-config/firmware/profiles/octopus-f446-usb-can.config .config
make olddefconfig
make clean
make
cp out/klipper.bin ~/printer-config/firmware/octopus-usb-can/firmware.bin
```

Octopus as plain USB MCU:

```bash
cd ~/klipper
cp ~/printer-config/firmware/profiles/octopus-f446-usb.config .config
make olddefconfig
make clean
make
cp out/klipper.bin ~/printer-config/firmware/octopus-usb/firmware.bin
```

Then build EBB42:

```bash
cd ~/klipper
cp ~/printer-config/firmware/profiles/ebb42-g0b1-can.config .config
make olddefconfig
make clean
make
cp out/klipper.bin ~/printer-config/firmware/ebb42/firmware.bin
```

Then build U2C v2.1:

```bash
cd ~/klipper
cp ~/printer-config/firmware/profiles/u2c-v21-g0b1-usb-can.config .config
make olddefconfig
make clean
make
cp out/klipper.bin ~/printer-config/firmware/u2c-v21/firmware.bin
```

## Flashing Workflows

Primary flashing workflow depends on the target board:

- Octopus: SD card
- EBB42: USB DFU via STM32CubeProgrammer
- U2C v2.1: microSD card

## Topology Warnings

- If the printer uses a dedicated U2C bridge, flash Octopus with `octopus-f446-usb.config`, not the bridge profile.
- If Octopus is the active USB-to-CAN bridge, do not also use a U2C as the host bridge on the same Klipper host.
- Power the printer off before moving BOOT jumpers, inserting/removing SD cards, or connecting/disconnecting CAN wiring.
- For EBB42 USB DFU, disconnect the printer-side CAN and 24V harness before plugging the board into USB to avoid dual-powering the toolhead board.

### Octopus (USB-to-CAN bridge mode)

1. Copy `firmware.bin` to an SD card.
2. Insert the SD card into the Octopus board.
3. Power cycle the board and wait for the flash to complete.

### Octopus (plain USB mode)

1. Copy `firmware.bin` to an SD card.
2. Insert the SD card into the Octopus board.
3. Power cycle the board and wait for the flash to complete.
4. Use this build when Klipper talks to Octopus over USB and a separate U2C provides the CAN interface.

### EBB42

1. Enter DFU mode on the EBB42 target board.
2. Connect in STM32CubeProgrammer as a USB target.
3. Load the EBB42 `firmware.bin`.
4. Use flash start address `0x08000000`.
5. Flash, verify, remove BOOT mode, and power cycle.

### U2C v2.1

1. Rename the downloaded `.bin` file to `firmware.bin`.
2. Copy `firmware.bin` to the root of a microSD card.
3. Insert the card into the U2C v2.1.
4. Power cycle or reset the adapter and wait for the flash to complete.

## UUID Discovery and Assignment

Primary method (recommended): Mainsail UI.

1. Open `Machine -> Devices -> CAN`.
2. Refresh and list unassigned UUIDs.
3. If needed, identify boards by disconnecting/reconnecting EBB42 CAN cable and refreshing.
4. Write values into `local/mcus.cfg`.
5. Restart Klipper and verify both MCUs initialize.

Secondary method (CLI fallback):

```bash
~/klippy-env/bin/python ~/klipper/scripts/canbus_query.py can0
```

## Provenance Rules for Firmware Updates

When updating any `firmware.bin`, update this file with:

- Build date
- Klipper commit/tag
- Profile used
- Operator initials or CI job reference

## Current Artifact Status

- `octopus-usb-can/firmware.bin`: local staging only
- `octopus-usb/firmware.bin`: local staging only
- `ebb42/firmware.bin`: local staging only
- `u2c-v21/firmware.bin`: local staging only

Validated binaries must be committed only after successful flash and boot verification on target hardware.

## Published Downloads (GitHub Pages)

Publish end-user downloadable binaries from `docs/firmware/latest/` with a stable URL.

- Manifest URL: `https://crafter3d.github.io/printer-config/firmware/latest/manifest.json`
- Guide URL: `https://crafter3d.github.io/printer-config/firmware/`

Each published binary must include Klipper version/commit metadata in the manifest.

## Publishing Process (GitHub Workflow)

Use workflow dispatch in GitHub Actions to publish latest binaries:

- Workflow: `.github/workflows/publish-firmware.yml`
- Build source: Klipper repository at selected `klipper_ref`
- Build profiles: `firmware/profiles/octopus-f446-usb-can.config`, `firmware/profiles/octopus-f446-usb.config`, `firmware/profiles/ebb42-g0b1-can.config`, `firmware/profiles/u2c-v21-g0b1-usb-can.config`
- Output publish path: `docs/firmware/latest/`

The workflow computes SHA256 checksums, updates `manifest.json`, archives the
previous `latest` into `docs/firmware/releases/`, and commits changes to `main`.
