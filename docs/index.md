# Crafter3D Firmware Portal

Official firmware downloads and setup guidance for Crafter 3D M6 CAN boards.

## Download Latest Firmware

- [Download Octopus Firmware (.bin)](firmware/latest/octopus-f446-usb-can.bin)
- [Download EBB42 Firmware (.bin)](firmware/latest/ebb42-g0b1-can.bin)
- [Firmware Manifest (version, checksum, metadata)](firmware/latest/manifest.json)
- Latest Klipper reference: <!--LATEST_KLIPPER_REF_START-->`v0.13.0 (61c0c8d2ef40340781835dd53fb04cc7a454e37a)`<!--LATEST_KLIPPER_REF_END-->

## Guides

- [Flashing and UUID Provisioning Guide](firmware/)
- [Release History](firmware/releases/)

## Supported Boards

- BTT Octopus v1.x (STM32F446, USB-to-CAN bridge)
- BTT EBB42 v1.1 (STM32G0B1, CAN)

## Safety Notes

- Confirm the board model before flashing.
- Verify firmware checksum from the manifest.
- Confirm Klipper version/commit compatibility from the manifest before updating.
