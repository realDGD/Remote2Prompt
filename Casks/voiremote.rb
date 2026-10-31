cask "voiremote" do
  version "0.3.4"
  sha256 "12f838a670c96b01cf4f34c4bd71a82229700c84aa245b0166cff1a3be4ed7e6"

  url "https://github.com/realDGD/VoiRemote/archive/795bd06b64fc138c1d48a0fce73fb1f9bd4343a6.tar.gz"
  name "VoiRemote"
  desc "Native macOS remote key mapping and voice app compiled with CLT"
  homepage "https://github.com/realDGD/VoiRemote"

  depends_on macos: :sonoma

  preflight_steps do
    run "/bin/bash", args: ["scripts/build-cask.sh", "0.3.4", "795bd06b64fc138c1d48a0fce73fb1f9bd4343a6", "12f838a670c96b01cf4f34c4bd71a82229700c84aa245b0166cff1a3be4ed7e6"],
                      chdir: "VoiRemote-795bd06b64fc138c1d48a0fce73fb1f9bd4343a6", print_stdout: true,
                      env: { "DEVELOPER_DIR" => "/Library/Developer/CommandLineTools" }
  end

  installer script: {
    executable: "VoiRemote-795bd06b64fc138c1d48a0fce73fb1f9bd4343a6/scripts/install-cask-app.sh",
    args: ["#{appdir}/VoiRemote.app", "795bd06b64fc138c1d48a0fce73fb1f9bd4343a6"],
  }
  binary "VoiRemote-795bd06b64fc138c1d48a0fce73fb1f9bd4343a6/packaging/homebrew/voiremote"

  postflight_steps do
    remove ["VoiRemote-795bd06b64fc138c1d48a0fce73fb1f9bd4343a6/.build", "VoiRemote-795bd06b64fc138c1d48a0fce73fb1f9bd4343a6/.swiftpm"], recursive: true
  end

  uninstall quit: "dev.voiremote.app",
            script: {
              executable: "VoiRemote-795bd06b64fc138c1d48a0fce73fb1f9bd4343a6/scripts/uninstall-cask-app.sh",
              args: ["#{appdir}/VoiRemote.app", "795bd06b64fc138c1d48a0fce73fb1f9bd4343a6"],
            }

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
