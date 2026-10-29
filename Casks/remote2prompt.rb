cask "remote2prompt" do
  version "0.2.13"
  sha256 "84a5a5a008cc26d99741ceb97c69b14de6755151658c00d69acca34a6bbb84e1"

  url "https://github.com/realDGD/Remote2Prompt/archive/8c57e5f1cbc3bae1a554b05905882fe563f25523.tar.gz"
  name "Remote2Prompt"
  desc "Native macOS remote key mapping and voice app compiled with CLT"
  homepage "https://github.com/realDGD/Remote2Prompt"

  depends_on macos: :sonoma

  preflight_steps do
    run "/bin/bash", args: ["scripts/build-cask.sh", "0.2.13", "8c57e5f1cbc3bae1a554b05905882fe563f25523", "84a5a5a008cc26d99741ceb97c69b14de6755151658c00d69acca34a6bbb84e1"],
                      chdir: "Remote2Prompt-8c57e5f1cbc3bae1a554b05905882fe563f25523", print_stdout: true,
                      env: { "DEVELOPER_DIR" => "/Library/Developer/CommandLineTools" }
  end

  app "Remote2Prompt-8c57e5f1cbc3bae1a554b05905882fe563f25523/dist/Remote2Prompt.app"
  binary "Remote2Prompt-8c57e5f1cbc3bae1a554b05905882fe563f25523/packaging/homebrew/remote2prompt"

  postflight_steps do
    remove ["Remote2Prompt-8c57e5f1cbc3bae1a554b05905882fe563f25523/.build", "Remote2Prompt-8c57e5f1cbc3bae1a554b05905882fe563f25523/.swiftpm"], recursive: true
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
