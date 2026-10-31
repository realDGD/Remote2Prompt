#!/bin/bash
set -euo pipefail
repo_dir="$(cd "$(dirname "$0")/.." && pwd)"
source "$repo_dir/scripts/toolchain.sh"
cd "$repo_dir"
voi_swiftpm run VoiRemoteChecks
voi_swiftpm run VoiRemoteMacChecks
