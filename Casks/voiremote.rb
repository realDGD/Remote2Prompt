cask "voiremote" do
  version "0.3.3"
  sha256 "2352f7c24afb2685573fc58bd0f9a12a864d911b66da547f2e2ac01249c5921b"

  url "https://github.com/realDGD/VoiRemote/archive/27076da60f88e0bc9c07800eb52185cc0762795e.tar.gz"
  name "VoiRemote"
  desc "Native macOS remote key mapping and voice app compiled with CLT"
  homepage "https://github.com/realDGD/VoiRemote"

  depends_on macos: :sonoma

  preflight_steps do
    run "/bin/bash", args: ["scripts/build-cask.sh", "0.3.3", "27076da60f88e0bc9c07800eb52185cc0762795e", "2352f7c24afb2685573fc58bd0f9a12a864d911b66da547f2e2ac01249c5921b"],
                      chdir: "VoiRemote-27076da60f88e0bc9c07800eb52185cc0762795e", print_stdout: true,
                      env: { "DEVELOPER_DIR" => "/Library/Developer/CommandLineTools" }
  end

  installer script: {
    executable: "VoiRemote-27076da60f88e0bc9c07800eb52185cc0762795e/scripts/install-cask-app.sh",
    args: ["#{appdir}/VoiRemote.app", "27076da60f88e0bc9c07800eb52185cc0762795e"],
  }
  binary "VoiRemote-27076da60f88e0bc9c07800eb52185cc0762795e/packaging/homebrew/voiremote"

  postflight_steps do
    remove ["VoiRemote-27076da60f88e0bc9c07800eb52185cc0762795e/.build", "VoiRemote-27076da60f88e0bc9c07800eb52185cc0762795e/.swiftpm"], recursive: true
  end

  uninstall quit: "dev.voiremote.app",
            script: {
              executable: "VoiRemote-27076da60f88e0bc9c07800eb52185cc0762795e/scripts/uninstall-cask-app.sh",
              args: ["#{appdir}/VoiRemote.app", "27076da60f88e0bc9c07800eb52185cc0762795e"],
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
