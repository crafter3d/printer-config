#!/bin/bash
set -e

# Creates/refreshes symlinks from ~/printer_data/config into ~/printer-config
: "${HOME:=/home/$(whoami)}"
CONFIG_DIR="${HOME}/printer_data/config"
REPO_DIR="${HOME}/printer-config"

if [[ ! -d "${CONFIG_DIR}" || ! -d "${REPO_DIR}" ]]; then
    echo "Expected directories missing: CONFIG_DIR=${CONFIG_DIR}, REPO_DIR=${REPO_DIR}" >&2
    exit 1
fi

# Symlink printer.cfg
ln -sf "$REPO_DIR/printer.cfg" "$CONFIG_DIR/printer.cfg"

# Symlink all content directories (skip scripts, .git, firmware artifacts)
for dir in "$REPO_DIR"/*/; do
    dirname=$(basename "$dir")
    [[ "$dirname" == "scripts" || "$dirname" == ".git" || "$dirname" == "firmware" ]] && continue
    ln -sf "$REPO_DIR/$dirname" "$CONFIG_DIR/$dirname"
done
