#!/bin/bash
# Keep a real bundle in Homebrew staging until it finalizes removal or rollback.
source "$(dirname "${BASH_SOURCE[0]}")/cask-app-common.sh"
if [[ ! -e "$app" && ! -L "$app" ]]; then exit 0; fi
owned_app "$app" || fail "Refusing to remove an application not owned by this source receipt."
if [[ -e "$staged_app" || -L "$staged_app" ]]; then
    own_alias || fail "Refusing to overwrite an existing staging backup."
fi
require_stopped
"$app/Contents/MacOS/VoiRemote" --unregister-login-item
if own_alias; then /bin/rm "$staged_app"; fi
if ! /bin/mv "$app" "$staged_app"; then
    # A failed move must not silently leave the old installation without login recovery.
    if [[ ! -e "$app" ]] && owned_app "$staged_app"; then /bin/mv "$staged_app" "$app"; fi
    if owned_app "$app"; then
        if [[ ! -e "$staged_app" && ! -L "$staged_app" ]]; then /bin/ln -s "$app" "$staged_app"; fi
        "$app/Contents/MacOS/VoiRemote" --restore-login-item || true
    fi
    fail "Could not return the app bundle to Homebrew staging."
fi
