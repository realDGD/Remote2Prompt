#!/bin/bash
set -euo pipefail
repo_dir="$(cd "$(dirname "$0")/.." && pwd)"
source "$repo_dir/scripts/toolchain.sh"
cd "$repo_dir"
r2p_swiftpm run Remote2PromptChecks
r2p_swiftpm run Remote2PromptMacChecks
