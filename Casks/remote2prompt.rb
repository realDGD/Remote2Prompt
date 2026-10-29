cask "remote2prompt" do
  version "0.2.14"
  sha256 "fe928945c37387076dd7bb243935c46cc6fa07bf56ebc5836548cf50092e7d59"

  url "https://github.com/realDGD/Remote2Prompt/archive/deef4b955cb952570f46d992b48e63c241a5ccd5.tar.gz"
  name "Remote2Prompt"
  desc "Native macOS remote key mapping and voice app compiled with CLT"
  homepage "https://github.com/realDGD/Remote2Prompt"

  depends_on macos: :sonoma

  preflight_steps do
    run "/bin/bash", args: ["scripts/build-cask.sh", "0.2.14", "deef4b955cb952570f46d992b48e63c241a5ccd5", "fe928945c37387076dd7bb243935c46cc6fa07bf56ebc5836548cf50092e7d59"],
                      chdir: "Remote2Prompt-deef4b955cb952570f46d992b48e63c241a5ccd5", print_stdout: true,
                      env: { "DEVELOPER_DIR" => "/Library/Developer/CommandLineTools" }
  end

  app "Remote2Prompt-deef4b955cb952570f46d992b48e63c241a5ccd5/dist/Remote2Prompt.app"
  binary "Remote2Prompt-deef4b955cb952570f46d992b48e63c241a5ccd5/packaging/homebrew/remote2prompt"

  postflight_steps do
    remove ["Remote2Prompt-deef4b955cb952570f46d992b48e63c241a5ccd5/.build", "Remote2Prompt-deef4b955cb952570f46d992b48e63c241a5ccd5/.swiftpm"], recursive: true
  end

  uninstall quit: "dev.remote2prompt.app"

  zap trash: [
    "~/Library/Application Support/Remote2Prompt",
    "~/Library/Caches/dev.remote2prompt.app",
    "~/Library/Preferences/ByHost/dev.remote2prompt.app.*.plist",
    "~/Library/Preferences/dev.remote2prompt.app.plist",
    "~/Library/Saved Application State/dev.remote2prompt.app.savedState",
  ]

  caveats <<~EOS
    This single cask compiles the fixed source archive using Swift 6 Command Line Tools.
    It installs one app in Applications; no companion formula or audio driver is installed.
    Source builds use identifier-only ad-hoc signing, which does not authenticate the signer.
    Changing from older hash-bound builds may require re-authorizing this app once.
    Gatekeeper approval is separate; this app is not Developer ID signed or notarized.
    Run remote2prompt --self-check to check the installed configuration code without devices.
    Uninstall with brew uninstall --cask realdgd/remote2prompt/remote2prompt; add --zap to clear this app's settings.
    brew test supports formulae only; source checks run during installation.
  EOS
end
