cask "remote2prompt" do
  version "0.2.2"
  sha256 "009ee5e1c14678b7db377f2cb6ce1eed86a4f8c5186be2796ad008a4f9602404"

  url "https://github.com/realDGD/Remote2Prompt/archive/ee59f4e23a08af1513949c6cde3061ef8ec1868d.tar.gz"
  name "Remote2Prompt"
  desc "Native macOS remote key mapping and voice app compiled with CLT"
  homepage "https://github.com/realDGD/Remote2Prompt"

  depends_on macos: :sonoma

  preflight_steps do
    run "/bin/bash", args: ["scripts/build-cask.sh", "0.2.2", "ee59f4e23a08af1513949c6cde3061ef8ec1868d", "009ee5e1c14678b7db377f2cb6ce1eed86a4f8c5186be2796ad008a4f9602404"],
                      chdir: "Remote2Prompt-ee59f4e23a08af1513949c6cde3061ef8ec1868d", print_stdout: true,
                      env: { "DEVELOPER_DIR" => "/Library/Developer/CommandLineTools" }
  end

  app "Remote2Prompt-ee59f4e23a08af1513949c6cde3061ef8ec1868d/dist/Remote2Prompt.app"
  binary "Remote2Prompt-ee59f4e23a08af1513949c6cde3061ef8ec1868d/packaging/homebrew/remote2prompt"

  postflight_steps do
    remove ["Remote2Prompt-ee59f4e23a08af1513949c6cde3061ef8ec1868d/.build", "Remote2Prompt-ee59f4e23a08af1513949c6cde3061ef8ec1868d/.swiftpm"], recursive: true
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
