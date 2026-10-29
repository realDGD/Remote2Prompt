cask "remote2prompt" do
  version "0.2.12"
  sha256 "ab8f3e300262c4761bf19dabb4b949b7e50f91551732c58f2f77cdfebe122f2f"

  url "https://github.com/realDGD/Remote2Prompt/archive/18cb09b779bb01ca1218fc03f4ae215a9195a72c.tar.gz"
  name "Remote2Prompt"
  desc "Native macOS remote key mapping and voice app compiled with CLT"
  homepage "https://github.com/realDGD/Remote2Prompt"

  depends_on macos: :sonoma

  preflight_steps do
    run "/bin/bash", args: ["scripts/build-cask.sh", "0.2.12", "18cb09b779bb01ca1218fc03f4ae215a9195a72c", "ab8f3e300262c4761bf19dabb4b949b7e50f91551732c58f2f77cdfebe122f2f"],
                      chdir: "Remote2Prompt-18cb09b779bb01ca1218fc03f4ae215a9195a72c", print_stdout: true,
                      env: { "DEVELOPER_DIR" => "/Library/Developer/CommandLineTools" }
  end

  app "Remote2Prompt-18cb09b779bb01ca1218fc03f4ae215a9195a72c/dist/Remote2Prompt.app"
  binary "Remote2Prompt-18cb09b779bb01ca1218fc03f4ae215a9195a72c/packaging/homebrew/remote2prompt"

  postflight_steps do
    remove ["Remote2Prompt-18cb09b779bb01ca1218fc03f4ae215a9195a72c/.build", "Remote2Prompt-18cb09b779bb01ca1218fc03f4ae215a9195a72c/.swiftpm"], recursive: true
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
    Run remote2prompt --self-check to check the installed configuration code without devices.
    Uninstall with brew uninstall --cask realdgd/remote2prompt/remote2prompt; add --zap to clear this app's settings.
    brew test supports formulae only; source checks run during installation.
  EOS
end
