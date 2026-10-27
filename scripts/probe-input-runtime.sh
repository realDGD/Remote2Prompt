#!/bin/bash
# No app bundle, devices, permissions, event injection or real system-default writes.
set -euo pipefail
repo_dir="$(cd "$(dirname "$0")/.." && pwd)"
source "$repo_dir/scripts/toolchain.sh"
out="$repo_dir/.build/probes/input-runtime"
mkdir -p "$out"
cd "$repo_dir"
/usr/bin/xcrun swiftc -swift-version 6 -O -emit-library -emit-module -module-name Remote2PromptCore \
  -module-cache-path "$out/cache" -emit-module-path "$out/Remote2PromptCore.swiftmodule" \
  "$repo_dir"/Sources/Remote2PromptCore/*.swift -o "$out/libRemote2PromptCore.dylib"
/usr/bin/xcrun swiftc -swift-version 6 -O -parse-as-library -I "$out" -L "$out" -lRemote2PromptCore \
  -Xlinker -rpath -Xlinker "$out" -module-cache-path "$out/cache" \
  Sources/Remote2PromptMac/InputPriorityCoordinator.swift Sources/Remote2PromptMac/AudioInputPriorityRuntime.swift \
  Sources/Remote2PromptMac/SystemAudioInputs.swift Sources/Remote2PromptMac/LoopbackDevices.swift \
  scripts/probes/InputRuntimeProbe.swift -o "$out/probe"
"$out/probe"
