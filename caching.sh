#!/usr/bin/env bash
QS_CACHE_BASE="${XDG_CACHE_HOME:-$HOME/.cache}/quickshell"

qs_ensure_cache() {
    local name="$1"
    local upper_name
    upper_name=$(echo "$name" | tr '[:lower:]' '[:upper:]')
    local dir="$QS_CACHE_BASE/$name"
    mkdir -p "$dir"
    export "QS_CACHE_${upper_name}=$dir"
}
