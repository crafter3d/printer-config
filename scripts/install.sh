#!/bin/bash
set -euo pipefail

# Copies/refreshes managed printer-config content into ~/printer_data/config
: "${HOME:=/home/$(whoami)}"
CONFIG_DIR="${HOME}/printer_data/config"
REPO_DIR="${HOME}/printer-config"

MANAGED_DIRS=(
    autolevelling
    cooling
    display
    hardware
    heated_bed
    input_shaper
    led
    macros
    motors
    temperature
    toolhead
)

if [[ ! -d "${CONFIG_DIR}" || ! -d "${REPO_DIR}" ]]; then
    echo "Expected directories missing: CONFIG_DIR=${CONFIG_DIR}, REPO_DIR=${REPO_DIR}" >&2
    exit 1
fi

# Preserve local SAVE_CONFIG block from destination printer.cfg, if present.
save_cfg_tmp="$(mktemp)"
printer_cfg_tmp="$(mktemp)"

cleanup() {
    rm -f "${save_cfg_tmp}" "${printer_cfg_tmp}"
}
trap cleanup EXIT

if [[ -f "${CONFIG_DIR}/printer.cfg" ]]; then
    awk '/^#\*# <---- SAVE_CONFIG ---->/{found=1} found {print}' "${CONFIG_DIR}/printer.cfg" > "${save_cfg_tmp}" || true
fi

awk 'BEGIN{stop=0} /^#\*# <---- SAVE_CONFIG ---->/{stop=1} !stop{print}' "${REPO_DIR}/printer.cfg" > "${printer_cfg_tmp}"

if [[ -s "${save_cfg_tmp}" ]]; then
    cat "${save_cfg_tmp}" >> "${printer_cfg_tmp}"
fi

# Force overwrite managed printer.cfg as a regular file.
if [[ -e "${CONFIG_DIR}/printer.cfg" || -L "${CONFIG_DIR}/printer.cfg" ]]; then
    rm -f "${CONFIG_DIR}/printer.cfg"
fi
install -m 0644 "${printer_cfg_tmp}" "${CONFIG_DIR}/printer.cfg"

# Force overwrite managed include directories as real copies.
for dirname in "${MANAGED_DIRS[@]}"; do
    src_dir="${REPO_DIR}/${dirname}"
    dst_dir="${CONFIG_DIR}/${dirname}"

    if [[ ! -d "${src_dir}" ]]; then
        echo "WARNING: missing managed directory in repository: ${src_dir}" >&2
        continue
    fi

    if [[ -L "${dst_dir}" ]]; then
        rm -f "${dst_dir}"
    elif [[ -e "${dst_dir}" ]]; then
        rm -rf "${dst_dir}"
    fi

    cp -a "${src_dir}" "${dst_dir}"
done

echo "Refreshed printer-config copies in ${CONFIG_DIR}"
