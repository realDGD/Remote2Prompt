cask "voiremote" do
  version "0.3.2"
  sha256 "48ebd46b1a5d33de3c423f648c65698edde8fe92729742737c3234ff9acae5db"

  url "https://github.com/realDGD/VoiRemote/archive/e754b16ae462f5e3ceb9f16449095025993152bd.tar.gz"
  name "VoiRemote"
  desc "Native macOS remote key mapping and voice app compiled with CLT"
  homepage "https://github.com/realDGD/VoiRemote"

  depends_on macos: :sonoma

  preflight_steps do
    run "/bin/bash", args: ["scripts/build-cask.sh", "0.3.2", "e754b16ae462f5e3ceb9f16449095025993152bd", "48ebd46b1a5d33de3c423f648c65698edde8fe92729742737c3234ff9acae5db"],
                      chdir: "VoiRemote-e754b16ae462f5e3ceb9f16449095025993152bd", print_stdout: true,
                      env: { "DEVELOPER_DIR" => "/Library/Developer/CommandLineTools" }
  end

  app "VoiRemote-e754b16ae462f5e3ceb9f16449095025993152bd/dist/VoiRemote.app"
  binary "VoiRemote-e754b16ae462f5e3ceb9f16449095025993152bd/packaging/homebrew/voiremote"

  postflight_steps do
    remove ["VoiRemote-e754b16ae462f5e3ceb9f16449095025993152bd/.build", "VoiRemote-e754b16ae462f5e3ceb9f16449095025993152bd/.swiftpm"], recursive: true
    run "VoiRemote.app/Contents/MacOS/VoiRemote", base: :appdir,
        args: ["--restore-login-item"], print_stdout: true, must_succeed: false
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
