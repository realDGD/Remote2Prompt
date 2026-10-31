#!/bin/bash
# No app bundle, devices, permissions, event injection or real system-default writes.
set -euo pipefail
repo_dir="$(cd "$(dirname "$0")/.." && pwd)"
source "$repo_dir/scripts/toolchain.sh"
out="$repo_dir/.build/probes/input-runtime"
mkdir -p "$out"
cd "$repo_dir"
/usr/bin/xcrun swiftc -swift-version 6 -O -emit-library -emit-module -module-name VoiRemoteCore \
  -module-cache-path "$out/cache" -emit-module-path "$out/VoiRemoteCore.swiftmodule" \
  "$repo_dir"/Sources/VoiRemoteCore/*.swift -o "$out/libVoiRemoteCore.dylib"
/usr/bin/xcrun swiftc -swift-version 6 -O -parse-as-library -I "$out" -L "$out" -lVoiRemoteCore \
  -Xlinker -rpath -Xlinker "$out" -module-cache-path "$out/cache" \
  Sources/VoiRemoteMac/InputPriorityCoordinator.swift Sources/VoiRemoteMac/AudioInputPriorityRuntime.swift \
  Sources/VoiRemoteMac/SystemAudioInputs.swift Sources/VoiRemoteMac/LoopbackDevices.swift \
  scripts/probes/InputRuntimeProbe.swift -o "$out/probe"
"$out/probe"
