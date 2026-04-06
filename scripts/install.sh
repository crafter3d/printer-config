#!/bin/bash
set -euo pipefail

# Installs printer-config with a local entrypoint and mode-aware managed assets.
: "${HOME:=/home/$(whoami)}"
CONFIG_DIR="${HOME}/printer_data/config"
REPO_DIR="${HOME}/printer-config"
MODE="${1:-${INSTALL_MODE:-symlink}}"

MANAGED_PATHS=(
    printer.managed.cfg:printer.cfg
    display
    macros
)

LOCAL_DIR="${CONFIG_DIR}/local"
LOCAL_GENERATED_DIR="${LOCAL_DIR}/generated"
TEMPLATES_DIR="${REPO_DIR}/local_templates"

LOCAL_CLIENT_VARS_FILE="${LOCAL_DIR}/client_variables.cfg"
LOCAL_MCUS_FILE="${LOCAL_DIR}/mcus.cfg"
LOCAL_NETWORK_INFO_FILE="${LOCAL_GENERATED_DIR}/network_info_values.cfg"
LOCAL_PRINTER_CFG_FILE="${CONFIG_DIR}/printer.cfg"

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

ensure_parent_dir() {
    local path="$1"
    mkdir -p "$(dirname "${path}")"
}

seed_local_file() {
    local destination="$1"
    local template="$2"
    local label="$3"

    if [[ -f "${destination}" ]]; then
        echo "Preserved existing local ${label}: ${destination}"
        return 0
    fi

    ensure_parent_dir "${destination}"

    if [[ ! -f "${template}" ]]; then
        echo "Missing template for ${label}: ${template}" >&2
        exit 1
    fi

    install -m 0644 "${template}" "${destination}"
    echo "Seeded default local ${label}: ${destination}"
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
    local mapping="$1"
    local destination_rel
    local source_rel

    if [[ "${mapping}" == *:* ]]; then
        destination_rel="${mapping%%:*}"
        source_rel="${mapping##*:}"
    else
        destination_rel="${mapping}"
        source_rel="${mapping}"
    fi

    local source_path="${REPO_DIR}/${source_rel}"
    local destination_path="${CONFIG_DIR}/${destination_rel}"

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

seed_local_file "${LOCAL_CLIENT_VARS_FILE}" "${TEMPLATES_DIR}/client_variables.cfg" "client variables"
seed_local_file "${LOCAL_MCUS_FILE}" "${TEMPLATES_DIR}/mcus.cfg" "MCU parameters"
seed_local_file "${LOCAL_NETWORK_INFO_FILE}" "${TEMPLATES_DIR}/generated/network_info_values.cfg" "network info values"
seed_local_file "${LOCAL_PRINTER_CFG_FILE}" "${TEMPLATES_DIR}/printer.cfg" "printer entrypoint"

for rel_path in "${MANAGED_PATHS[@]}"; do
    refresh_managed_path "${rel_path}"
done

echo "Installed printer-config in ${MODE} mode with local entrypoint and managed repo links"
