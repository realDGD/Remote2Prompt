cask "voiremote" do
  version "0.3.0"
  sha256 "56c15ffa5d8001508ccf62c4645d6ef41753ca268c58f49fe22c08c3ef27c1dc"

  url "https://github.com/realDGD/VoiRemote/archive/ad9140ca389be71960edc9a9f76e315e12ad6916.tar.gz"
  name "VoiRemote"
  desc "Native macOS remote key mapping and voice app compiled with CLT"
  homepage "https://github.com/realDGD/VoiRemote"

  depends_on macos: :sonoma

  preflight_steps do
    run "/bin/bash", args: ["scripts/build-cask.sh", "0.3.0", "ad9140ca389be71960edc9a9f76e315e12ad6916", "56c15ffa5d8001508ccf62c4645d6ef41753ca268c58f49fe22c08c3ef27c1dc"],
                      chdir: "VoiRemote-ad9140ca389be71960edc9a9f76e315e12ad6916", print_stdout: true,
                      env: { "DEVELOPER_DIR" => "/Library/Developer/CommandLineTools" }
  end

  app "VoiRemote-ad9140ca389be71960edc9a9f76e315e12ad6916/dist/VoiRemote.app"
  binary "VoiRemote-ad9140ca389be71960edc9a9f76e315e12ad6916/packaging/homebrew/voiremote"

  postflight_steps do
    remove ["VoiRemote-ad9140ca389be71960edc9a9f76e315e12ad6916/.build", "VoiRemote-ad9140ca389be71960edc9a9f76e315e12ad6916/.swiftpm"], recursive: true
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
