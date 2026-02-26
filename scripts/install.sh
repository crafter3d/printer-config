#!/bin/bash
# Creates/refreshes symlinks from ~/printer_data/config into ~/printer-config
CONFIG_DIR="$HOME/printer_data/config"
REPO_DIR="$HOME/printer-config"

# Symlink printer.cfg
ln -sf "$REPO_DIR/printer.cfg" "$CONFIG_DIR/printer.cfg"

# Symlink all content directories (skip scripts, .git)
for dir in "$REPO_DIR"/*/; do
    dirname=$(basename "$dir")
    [[ "$dirname" == "scripts" || "$dirname" == ".git" ]] && continue
    ln -sf "$REPO_DIR/$dirname" "$CONFIG_DIR/$dirname"
done
