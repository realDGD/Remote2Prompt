#!/bin/bash
# Read-only WeType window geometry; output stays local and contains no window text or images.
set -euo pipefail
repo_dir="$(cd "$(dirname "$0")/.." && pwd)"
source "$repo_dir/scripts/toolchain.sh"
out="$repo_dir/.build/probes/wetype-windows"
mkdir -p "$out"
/usr/bin/xcrun swiftc -swift-version 6 -O -module-cache-path "$out/cache" \
    "$repo_dir/scripts/probes/WeTypeWindowProbe.swift" -o "$out/probe"
"$out/probe" "${1:-60}"
