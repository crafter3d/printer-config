# Firmware and Provisioning Guide

This page documents flashing and UUID provisioning for Crafter 3D M6.

## Firmware Download

Use the latest manifest:

- `latest/manifest.json`

The manifest maps each board to:

- binary file URL
- Klipper version or commit SHA
- profile used for build
- flash start address
- SHA256 checksum

## Publish Latest Firmware (Maintainers)

Use GitHub Actions workflow dispatch:

- Workflow: `.github/workflows/publish-firmware.yml`
- Required inputs: `klipper_ref`, `build_date`
- Optional input: `notes`
- Build inputs are taken from tracked profiles under `firmware/profiles/`

The workflow archives previous latest artifacts, publishes new binaries under
`firmware/latest/`, and regenerates `manifest.json`.

## Flashing (Windows, STM32CubeProgrammer)

1. Put target board in USB DFU mode.
2. Connect in STM32CubeProgrammer.
3. Select board binary from links in `latest/manifest.json`.
4. Use start address:
   - Octopus: `0x08008000`
   - EBB42: `0x08000000`
5. Flash, verify, and power cycle.

## UUID Discovery (Primary: Mainsail)

1. Open `Machine -> Devices -> CAN`.
2. Refresh and list unassigned UUIDs.
3. If needed, disconnect/reconnect EBB42 to map board identity.
4. Update `hardware/mcu.cfg` and restart Klipper.

## UUID Discovery (Fallback: CLI)

```bash
~/klippy-env/bin/python ~/klipper/scripts/canbus_query.py can0
```

## Verify in Klipper Log

Check recent MCU bring-up lines after restart:

```bash
grep -E 'mcu|MCU|canbus|error|timeout' ~/printer_data/logs/klippy.log | tail -30
```
