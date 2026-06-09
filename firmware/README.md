# Crafter3D Firmware Profiles and Artifacts

This directory defines the default firmware targets for Crafter 3D M6 CAN setup:

- Main board: BTT Octopus v1.x (STM32F446, USB-to-CAN bridge)
- Toolhead board: BTT EBB42 v1.1 (STM32G0B1, CAN)
- USB-to-CAN adapter: BTT U2C v2.1 (STM32G0B1, USB-to-CAN bridge)
- CAN bus speed: 1000000

## Repository Layout

- `profiles/octopus-f446-usb-can.config`: Klipper profile for Octopus.
- `profiles/ebb42-g0b1-can.config`: Klipper profile for EBB42.
- `profiles/u2c-v21-g0b1-usb-can.config`: Klipper profile for U2C v2.1.
- `octopus/firmware.bin`: Local/staging artifact path for Octopus.
- `ebb42/firmware.bin`: Local/staging artifact path for EBB42.
- `u2c-v21/firmware.bin`: Local/staging artifact path for U2C v2.1.
- `../docs/firmware/latest/manifest.json`: Published latest artifact metadata.

## Build Firmware from Profiles

Build on a Pi/host with Klipper source available:

```bash
cd ~/klipper
cp ~/printer-config/firmware/profiles/octopus-f446-usb-can.config .config
make olddefconfig
make clean
make
cp out/klipper.bin ~/printer-config/firmware/octopus/firmware.bin
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

### Octopus

1. Copy `firmware.bin` to an SD card.
2. Insert the SD card into the Octopus board.
3. Power cycle the board and wait for the flash to complete.

### EBB42

1. Enter DFU mode on the EBB42 target board.
2. Connect in STM32CubeProgrammer as a USB target.
3. Load the EBB42 `firmware.bin`.
4. Use flash start address `0x08000000`.
5. Flash, verify, remove BOOT mode, and power cycle.

### U2C v2.1

1. Copy `firmware.bin` to the root of a microSD card.
2. Insert the card into the U2C v2.1.
3. Power cycle or reset the adapter and wait for the flash to complete.

## UUID Discovery and Assignment

Primary method (recommended): Mainsail UI.

1. Open `Machine -> Devices -> CAN`.
2. Refresh and list unassigned UUIDs.
3. If needed, identify boards by disconnecting/reconnecting EBB42 CAN cable and refreshing.
4. Write UUIDs into `hardware/mcu.cfg`.
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

- `octopus/firmware.bin`: pending publication
- `ebb42/firmware.bin`: pending publication
- `u2c-v21/firmware.bin`: pending publication

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
- Build profiles: `firmware/profiles/octopus-f446-usb-can.config`, `firmware/profiles/ebb42-g0b1-can.config`
- Additional build profile: `firmware/profiles/u2c-v21-g0b1-usb-can.config`
- Output publish path: `docs/firmware/latest/`

The workflow computes SHA256 checksums, updates `manifest.json`, archives the
previous `latest` into `docs/firmware/releases/`, and commits changes to `main`.
