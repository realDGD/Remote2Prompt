---
name: r2p-check
description: Select and run relevant Remote2Prompt checks before reporting a code or packaging change complete. Distinguish CLT build evidence from UI, audio, permissions, and real remote validation.
---

# Remote2Prompt checks

Read [testing](../../../docs/testing.md) for the hardware matrix and [development](../../../docs/development.md) for CLT and Homebrew commands.

- Core behavior: `make test`, adding cases only for changed behavior or concrete failure modes.
- Application code or bundling: `make build` then `./scripts/verify-app.sh`; window lifecycle changes also need a real UI smoke.
- Note/docs-only changes: `make docs-check`.
- Homebrew changes: `make homebrew` is static generation only. Publish source, pin the actual HTTPS archive/hash, then install through a fresh public HTTPS tap when authorized. Never install from a local checkout or file URL. Run `scripts/verify-homebrew-install.sh` and actual Cask uninstall/zap checks; `brew test` only supports formulae. Do not claim installation from template syntax checks.

Use `make check` for changes spanning these surfaces. Default to standalone CLT; do not change global `xcode-select` or fall back silently to full Xcode. Re-run a passing check only after a relevant change or unresolved failure.

Report actual commands and outcomes. Pure policy tests do not prove CoreAudio writes; generated key events do not prove target input-method behavior; a visible settings window does not prove hardware support. Update the validation record and current capability table if scope changed.
