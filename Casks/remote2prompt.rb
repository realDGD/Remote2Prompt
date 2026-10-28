cask "remote2prompt" do
  version "0.2.4"
  sha256 "1d584662d918087fdcfcbd3b7d66b842e03ec7dcb894a818af8cb7c0602a2dd4"

  url "https://github.com/realDGD/Remote2Prompt/archive/9e4044429523d6921c875ba97855c21306cbd25d.tar.gz"
  name "Remote2Prompt"
  desc "Native macOS remote key mapping and voice app compiled with CLT"
  homepage "https://github.com/realDGD/Remote2Prompt"

  depends_on macos: :sonoma

  preflight_steps do
    run "/bin/bash", args: ["scripts/build-cask.sh", "0.2.4", "9e4044429523d6921c875ba97855c21306cbd25d", "1d584662d918087fdcfcbd3b7d66b842e03ec7dcb894a818af8cb7c0602a2dd4"],
                      chdir: "Remote2Prompt-9e4044429523d6921c875ba97855c21306cbd25d", print_stdout: true,
                      env: { "DEVELOPER_DIR" => "/Library/Developer/CommandLineTools" }
  end

  app "Remote2Prompt-9e4044429523d6921c875ba97855c21306cbd25d/dist/Remote2Prompt.app"
  binary "Remote2Prompt-9e4044429523d6921c875ba97855c21306cbd25d/packaging/homebrew/remote2prompt"

  postflight_steps do
    remove ["Remote2Prompt-9e4044429523d6921c875ba97855c21306cbd25d/.build", "Remote2Prompt-9e4044429523d6921c875ba97855c21306cbd25d/.swiftpm"], recursive: true
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
