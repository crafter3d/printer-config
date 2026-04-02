#!/bin/bash
set -euo pipefail

# Copies/refreshes managed printer-config content into ~/printer_data/config
: "${HOME:=/home/$(whoami)}"
CONFIG_DIR="${HOME}/printer_data/config"
REPO_DIR="${HOME}/printer-config"

# Match Klipper SAVE_CONFIG marker variants (different dash counts are common).
SAVE_CONFIG_MARKER_REGEX='^#\*# <[- ]*SAVE_CONFIG[- ]*>$'

MANAGED_DIRS=(
    display
    macros
)

if [[ ! -d "${CONFIG_DIR}" || ! -d "${REPO_DIR}" ]]; then
    echo "Expected directories missing: CONFIG_DIR=${CONFIG_DIR}, REPO_DIR=${REPO_DIR}" >&2
    exit 1
fi

# Preserve local MCU sections and SAVE_CONFIG block from destination printer.cfg, if present.
save_cfg_tmp="$(mktemp)"
mcu_sections_tmp="$(mktemp)"
base_cfg_tmp="$(mktemp)"
printer_cfg_tmp="$(mktemp)"

cleanup() {
    rm -f "${save_cfg_tmp}" "${mcu_sections_tmp}" "${base_cfg_tmp}" "${printer_cfg_tmp}"
}
trap cleanup EXIT

if [[ -f "${CONFIG_DIR}/printer.cfg" ]]; then
    awk '/^\[(mcu|mcu toolhead)\]$/ {capture=1} /^\[.*\]$/ && !/^\[(mcu|mcu toolhead)\]$/ {capture=0} capture {print}' "${CONFIG_DIR}/printer.cfg" > "${mcu_sections_tmp}" || true
    awk -v marker_re="${SAVE_CONFIG_MARKER_REGEX}" '$0 ~ marker_re {found=1} found {print}' "${CONFIG_DIR}/printer.cfg" > "${save_cfg_tmp}" || true
fi

awk -v marker_re="${SAVE_CONFIG_MARKER_REGEX}" 'BEGIN{stop=0} $0 ~ marker_re {stop=1} !stop{print}' "${REPO_DIR}/printer.cfg" > "${base_cfg_tmp}"

if [[ -s "${mcu_sections_tmp}" ]]; then
    base_no_mcu_tmp="$(mktemp)"
    awk '/^\[(mcu|mcu toolhead)\]$/ {skip=1; next} /^\[.*\]$/ {skip=0} !skip {print}' "${base_cfg_tmp}" > "${base_no_mcu_tmp}"

    awk -v mcu_file="${mcu_sections_tmp}" '
        {
            print
        }
        !inserted && /^\[include mainsail\.cfg\]$/ {
            print ""
            while ((getline line < mcu_file) > 0) {
                print line
            }
            close(mcu_file)
            print ""
            inserted=1
        }
        END {
            if (!inserted) {
                print ""
                while ((getline line < mcu_file) > 0) {
                    print line
                }
                close(mcu_file)
                print ""
            }
        }
    ' "${base_no_mcu_tmp}" > "${printer_cfg_tmp}"

    rm -f "${base_no_mcu_tmp}"
    echo "Preserved local MCU sections from existing printer.cfg"
else
    cp "${base_cfg_tmp}" "${printer_cfg_tmp}"
    echo "No local MCU sections found; using repository MCU block"
fi

if [[ -s "${save_cfg_tmp}" ]]; then
    printf '\n' >> "${printer_cfg_tmp}"
    cat "${save_cfg_tmp}" >> "${printer_cfg_tmp}"
    echo "Preserved local SAVE_CONFIG block from existing printer.cfg"
else
    echo "No local SAVE_CONFIG block found; using repository printer.cfg content only"
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
