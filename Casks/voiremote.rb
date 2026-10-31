cask "voiremote" do
  version "0.3.1"
  sha256 "c481b5462475855cdccb9c7eae91b92a09dbb4976013ef11af3b5e209c2e8bec"

  url "https://github.com/realDGD/VoiRemote/archive/93a31a8eaa1b8e4256268192e00d26f82340d4fc.tar.gz"
  name "VoiRemote"
  desc "Native macOS remote key mapping and voice app compiled with CLT"
  homepage "https://github.com/realDGD/VoiRemote"

  depends_on macos: :sonoma

  preflight_steps do
    run "/bin/bash", args: ["scripts/build-cask.sh", "0.3.1", "93a31a8eaa1b8e4256268192e00d26f82340d4fc", "c481b5462475855cdccb9c7eae91b92a09dbb4976013ef11af3b5e209c2e8bec"],
                      chdir: "VoiRemote-93a31a8eaa1b8e4256268192e00d26f82340d4fc", print_stdout: true,
                      env: { "DEVELOPER_DIR" => "/Library/Developer/CommandLineTools" }
  end

  app "VoiRemote-93a31a8eaa1b8e4256268192e00d26f82340d4fc/dist/VoiRemote.app"
  binary "VoiRemote-93a31a8eaa1b8e4256268192e00d26f82340d4fc/packaging/homebrew/voiremote"

  postflight_steps do
    remove ["VoiRemote-93a31a8eaa1b8e4256268192e00d26f82340d4fc/.build", "VoiRemote-93a31a8eaa1b8e4256268192e00d26f82340d4fc/.swiftpm"], recursive: true
  end

  uninstall quit: "dev.voiremote.app",
            script: { executable: "#{appdir}/VoiRemote.app/Contents/MacOS/VoiRemote", args: ["--unregister-login-item"] }

  zap trash: [
    "~/Library/Application Support/VoiRemote",
    "~/Library/Caches/dev.voiremote.app",
    "~/Library/Preferences/ByHost/dev.voiremote.app.*.plist",
    "~/Library/Preferences/dev.voiremote.app.plist",
    "~/Library/Saved Application State/dev.voiremote.app.savedState",
  ]

  caveats <<~EOS
    This single cask compiles the fixed source archive using Swift 6 Command Line Tools.
    It installs one app in Applications; no companion formula or audio driver is installed.
    Source builds use identifier-only ad-hoc signing, which does not authenticate the signer.
    Changing from older hash-bound builds may require re-authorizing this app once.
    Gatekeeper approval is separate; this app is not Developer ID signed or notarized.
    Run voiremote --self-check to check the installed configuration code without devices.
    Uninstall with brew uninstall --cask realdgd/voiremote/voiremote; add --zap to clear this app's settings.
    brew test supports formulae only; source checks run during installation.
  EOS
end
