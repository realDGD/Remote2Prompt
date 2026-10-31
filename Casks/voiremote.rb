cask "voiremote" do
  version "0.3.2"
  sha256 "fa09729cd77c7ad3f3caf010d34cc7517048140b8dc2ca5ea35272d7ed69b524"

  url "https://github.com/realDGD/VoiRemote/archive/3ba53f40893d36c864c9b188cc997acc22d50766.tar.gz"
  name "VoiRemote"
  desc "Native macOS remote key mapping and voice app compiled with CLT"
  homepage "https://github.com/realDGD/VoiRemote"

  depends_on macos: :sonoma

  preflight_steps do
    run "/bin/bash", args: ["scripts/build-cask.sh", "0.3.2", "3ba53f40893d36c864c9b188cc997acc22d50766", "fa09729cd77c7ad3f3caf010d34cc7517048140b8dc2ca5ea35272d7ed69b524"],
                      chdir: "VoiRemote-3ba53f40893d36c864c9b188cc997acc22d50766", print_stdout: true,
                      env: { "DEVELOPER_DIR" => "/Library/Developer/CommandLineTools" }
  end

  app "VoiRemote-3ba53f40893d36c864c9b188cc997acc22d50766/dist/VoiRemote.app"
  binary "VoiRemote-3ba53f40893d36c864c9b188cc997acc22d50766/packaging/homebrew/voiremote"

  postflight_steps do
    remove ["VoiRemote-3ba53f40893d36c864c9b188cc997acc22d50766/.build", "VoiRemote-3ba53f40893d36c864c9b188cc997acc22d50766/.swiftpm"], recursive: true
  end

  # ServiceManagement needs Mach services unavailable in the file-preparation sandbox.
  postflight do
    system_command "#{appdir}/VoiRemote.app/Contents/MacOS/VoiRemote",
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
