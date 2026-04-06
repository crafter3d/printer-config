#!/bin/bash
set -euo pipefail

# Installs printer-config with protected local files and mode-aware managed assets.
: "${HOME:=/home/$(whoami)}"
CONFIG_DIR="${HOME}/printer_data/config"
REPO_DIR="${HOME}/printer-config"
MODE="${1:-${INSTALL_MODE:-symlink}}"

# Match Klipper SAVE_CONFIG marker variants (different dash counts are common).
SAVE_CONFIG_MARKER_REGEX='^#\*# <[- ]*SAVE_CONFIG[- ]*>$'

MANAGED_PATHS=(
    printer.cfg
    display
    macros
)

LOCAL_DIR="${CONFIG_DIR}/local"
LOCAL_GENERATED_DIR="${LOCAL_DIR}/generated"
TEMPLATES_DIR="${REPO_DIR}/local_templates"

LOCAL_CLIENT_VARS_FILE="${LOCAL_DIR}/client_variables.cfg"
LOCAL_MCUS_FILE="${LOCAL_DIR}/mcus.cfg"
LOCAL_SAVE_CONFIG_FILE="${LOCAL_DIR}/save_config.cfg"
LOCAL_NETWORK_INFO_FILE="${LOCAL_GENERATED_DIR}/network_info_values.cfg"

LEGACY_PRINTER_CFG="${CONFIG_DIR}/printer.cfg"
LEGACY_SYSTEM_HELPERS_CFG="${CONFIG_DIR}/macros/system_helpers.cfg"
LEGACY_CLIENT_VARS_FROM_PRINTER_CFG="${CONFIG_DIR}/printer.cfg"
LEGACY_NETWORK_INFO_FILE="${CONFIG_DIR}/display/network_info_values.cfg"

TMP_DIR="$(mktemp -d)"
tmp_file_counter=0

new_tmp_file() {
    tmp_file_counter=$((tmp_file_counter + 1))
    printf '%s/file_%s.tmp' "${TMP_DIR}" "${tmp_file_counter}"
}

if [[ ! -d "${CONFIG_DIR}" || ! -d "${REPO_DIR}" ]]; then
    echo "Expected directories missing: CONFIG_DIR=${CONFIG_DIR}, REPO_DIR=${REPO_DIR}" >&2
    exit 1
fi

case "${MODE}" in
    symlink|copy)
        ;;
    *)
        echo "Unsupported install mode: ${MODE}. Supported values: symlink, copy" >&2
        exit 1
        ;;
esac

cleanup() {
    rm -rf "${TMP_DIR}"
}
trap cleanup EXIT

extract_mcu_sections() {
    local source_file="$1"
    local out_file="$2"
    awk '/^\[(mcu|mcu toolhead)\]$/ {capture=1} /^\[.*\]$/ && !/^\[(mcu|mcu toolhead)\]$/ {capture=0} capture {print}' "${source_file}" > "${out_file}" || true
}

extract_save_config_block() {
    local source_file="$1"
    local out_file="$2"
    awk -v marker_re="${SAVE_CONFIG_MARKER_REGEX}" '$0 ~ marker_re {found=1} found {print}' "${source_file}" > "${out_file}" || true
}

extract_client_variables() {
    local source_file="$1"
    local out_file="$2"
    awk '
        /^\[gcode_macro _CLIENT_VARIABLE\]$/ {capture=1}
        capture && /^\[.*\]$/ && !/^\[gcode_macro _CLIENT_VARIABLE\]$/ && seen {exit}
        capture {
            line=$0
            sub(/^variable_custom_park_z[[:space:]]*:/, "variable_custom_park_dz:", line)
            print line
            seen=1
        }
    ' "${source_file}" > "${out_file}" || true
}

ensure_parent_dir() {
    local path="$1"
    mkdir -p "$(dirname "${path}")"
}

seed_local_file() {
    local destination="$1"
    local template="$2"
    local legacy_source="$3"
    local extractor="$4"
    local label="$5"

    if [[ -f "${destination}" ]]; then
        echo "Preserved existing local ${label}: ${destination}"
        return 0
    fi

    ensure_parent_dir "${destination}"

    if [[ -n "${legacy_source}" && -f "${legacy_source}" && -n "${extractor}" ]]; then
        local extracted
        extracted="$(new_tmp_file)"
        "${extractor}" "${legacy_source}" "${extracted}"
        if [[ -s "${extracted}" ]]; then
            install -m 0644 "${extracted}" "${destination}"
            echo "Imported local ${label} from legacy config: ${legacy_source}"
            return 0
        fi
    fi

    if [[ -n "${legacy_source}" && -f "${legacy_source}" && -z "${extractor}" ]]; then
        install -m 0644 "${legacy_source}" "${destination}"
        echo "Imported local ${label} from legacy file: ${legacy_source}"
        return 0
    fi

    if [[ ! -f "${template}" ]]; then
        echo "Missing template for ${label}: ${template}" >&2
        exit 1
    fi

    install -m 0644 "${template}" "${destination}"
    echo "Seeded default local ${label}: ${destination}"
}

seed_client_variables() {
    if [[ -f "${LOCAL_CLIENT_VARS_FILE}" ]]; then
        echo "Preserved existing local client variables: ${LOCAL_CLIENT_VARS_FILE}"
        return 0
    fi

    ensure_parent_dir "${LOCAL_CLIENT_VARS_FILE}"

    for legacy_source in "${LEGACY_SYSTEM_HELPERS_CFG}" "${LEGACY_CLIENT_VARS_FROM_PRINTER_CFG}"; do
        if [[ -f "${legacy_source}" ]]; then
            local extracted
            extracted="$(new_tmp_file)"
            extract_client_variables "${legacy_source}" "${extracted}"
            if [[ -s "${extracted}" ]]; then
                install -m 0644 "${extracted}" "${LOCAL_CLIENT_VARS_FILE}"
                echo "Imported local client variables from legacy config: ${legacy_source}"
                return 0
            fi
        fi
    done

    install -m 0644 "${TEMPLATES_DIR}/client_variables.cfg" "${LOCAL_CLIENT_VARS_FILE}"
    echo "Seeded default local client variables: ${LOCAL_CLIENT_VARS_FILE}"
}

remove_destination_path() {
    local destination="$1"
    if [[ -L "${destination}" || -f "${destination}" ]]; then
        rm -f "${destination}"
    elif [[ -d "${destination}" ]]; then
        rm -rf "${destination}"
    fi
}

refresh_managed_path() {
    local rel_path="$1"
    local source_path="${REPO_DIR}/${rel_path}"
    local destination_path="${CONFIG_DIR}/${rel_path}"

    if [[ ! -e "${source_path}" ]]; then
        echo "WARNING: missing managed source path: ${source_path}" >&2
        return 0
    fi

    remove_destination_path "${destination_path}"

    if [[ "${MODE}" == "symlink" ]]; then
        ln -s "${source_path}" "${destination_path}"
    else
        if [[ -d "${source_path}" ]]; then
            cp -a "${source_path}" "${destination_path}"
        else
            install -m 0644 "${source_path}" "${destination_path}"
        fi
    fi
}

mkdir -p "${LOCAL_DIR}" "${LOCAL_GENERATED_DIR}"

seed_client_variables
seed_local_file "${LOCAL_MCUS_FILE}" "${TEMPLATES_DIR}/mcus.cfg" "${LEGACY_PRINTER_CFG}" extract_mcu_sections "MCU parameters"
seed_local_file "${LOCAL_SAVE_CONFIG_FILE}" "${TEMPLATES_DIR}/save_config.cfg" "${LEGACY_PRINTER_CFG}" extract_save_config_block "SAVE_CONFIG"
seed_local_file "${LOCAL_NETWORK_INFO_FILE}" "${TEMPLATES_DIR}/generated/network_info_values.cfg" "${LEGACY_NETWORK_INFO_FILE}" "" "network info values"

for rel_path in "${MANAGED_PATHS[@]}"; do
    refresh_managed_path "${rel_path}"
done

echo "Installed printer-config in ${MODE} mode with protected local files in ${LOCAL_DIR}"
