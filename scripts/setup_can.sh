#!/bin/bash
# Writes CAN UUIDs into ~/printer-config/hardware/mcu.cfg.
set -euo pipefail

REPO_DIR="${HOME}/printer-config"
MCU_CFG="${REPO_DIR}/hardware/mcu.cfg"

usage() {
    echo "Usage: $(basename "$0") <octopus_uuid> <ebb42_uuid>"
}

valid_uuid() {
    local value="$1"
    [[ "$value" =~ ^[0-9a-f]{12}$ ]]
}

if [[ $# -ne 2 ]]; then
    usage
    exit 1
fi

OCTOPUS_UUID="$1"
EBB42_UUID="$2"

if ! valid_uuid "$OCTOPUS_UUID"; then
    echo "Error: invalid Octopus UUID '$OCTOPUS_UUID'. Expected 12 lowercase hex chars." >&2
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
# 	MCU Configuration
#####################################################################

# UUIDs are unique per physical printer and must be assigned during provisioning.
# Primary flow: Mainsail -> Machine -> Devices -> CAN -> identify and copy UUIDs.
# Secondary flow: run canbus_query.py over SSH.

[mcu]
canbus_uuid=${OCTOPUS_UUID}

[mcu toolhead]
canbus_uuid=${EBB42_UUID}
EOF

cp "$TMP_FILE" "$MCU_CFG"

echo "Updated $MCU_CFG"
echo "  [mcu]          canbus_uuid=${OCTOPUS_UUID}"
echo "  [mcu toolhead] canbus_uuid=${EBB42_UUID}"
