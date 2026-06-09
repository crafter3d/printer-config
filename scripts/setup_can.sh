#!/bin/bash
# Writes the default USB-Octopus + U2C + EBB42 topology into ~/printer_data/config/local/mcus.cfg.
set -euo pipefail

CONFIG_DIR="${HOME}/printer_data/config"
MCU_CFG="${CONFIG_DIR}/local/mcus.cfg"

usage() {
    echo "Usage: $(basename "$0") <octopus_serial_path> <ebb42_uuid> [can_interface]"
}

valid_uuid() {
    local value="$1"
    [[ "$value" =~ ^[0-9a-f]{12}$ ]]
}

if [[ $# -lt 2 || $# -gt 3 ]]; then
    usage
    exit 1
fi

OCTOPUS_SERIAL="$1"
EBB42_UUID="$2"
CAN_INTERFACE="${3:-can0}"

if [[ "${OCTOPUS_SERIAL}" != /dev/serial/by-id/* ]]; then
    echo "Error: Octopus serial path must start with /dev/serial/by-id/." >&2
    exit 2
fi

if ! valid_uuid "$EBB42_UUID"; then
    echo "Error: invalid EBB42 UUID '$EBB42_UUID'. Expected 12 lowercase hex chars." >&2
    exit 2
fi

if [[ ! -f "$MCU_CFG" ]]; then
    echo "Error: config not found: $MCU_CFG" >&2
    exit 3
fi

if [[ ! -w "$MCU_CFG" ]]; then
    echo "Error: config is not writable: $MCU_CFG" >&2
    exit 4
fi

TMP_FILE="$(mktemp)"
cleanup() {
    rm -f "$TMP_FILE"
}
trap cleanup EXIT

cat > "$TMP_FILE" <<EOF
#####################################################################
#  Local MCU parameters (preserved across updates)
#####################################################################

# Default topology:
# - Octopus on direct USB
# - U2C v2.1 as the host CAN interface
# - EBB42 on CAN
#
# UUIDs are unique per physical printer and must be assigned during provisioning.
# Primary flow: Mainsail -> Machine -> Devices -> CAN -> identify and copy UUIDs.
# Secondary flow: run canbus_query.py over SSH.

[mcu]
serial: ${OCTOPUS_SERIAL}

[mcu toolhead]
canbus_uuid=${EBB42_UUID}
canbus_interface: ${CAN_INTERFACE}
EOF

cp "$TMP_FILE" "$MCU_CFG"

echo "Updated $MCU_CFG"
echo "  [mcu]          serial=${OCTOPUS_SERIAL}"
echo "  [mcu toolhead] canbus_uuid=${EBB42_UUID}"
echo "  [mcu toolhead] canbus_interface=${CAN_INTERFACE}"
