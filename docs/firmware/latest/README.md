# Latest Firmware Artifacts

This directory is published via GitHub Pages and should always contain:

- `manifest.json`
- latest Octopus binary (`octopus-f446-usb-can.bin`)
- latest EBB42 binary (`ebb42-g0b1-can.bin`)

The JSON manifest is the source of truth for compatibility and checksums.

## Update Policy

This directory is managed by the firmware publish workflow:

- `.github/workflows/publish-firmware.yml`

Do not update these files manually for releases. Publish via workflow dispatch
after validating firmware on hardware.
