cask "remote2prompt-app" do
  version "0.2.1"
  sha256 "5004536500ce03f8de8b8fb3b1450a52c34a22ab16a62387eb2c7c86ec8c0686"

  url "https://github.com/realDGD/Remote2Prompt/archive/1f91c0e0defa05896e4dea356df007160fb8d700.tar.gz"
  name "Remote2Prompt"
  desc "Native macOS remote key mapping and voice-trigger app built from source"
  homepage "https://github.com/realDGD/Remote2Prompt"

  depends_on formula: "realdgd/remote2prompt/remote2prompt"
  depends_on macos: :sonoma

  app "Remote2Prompt.app"

  preflight_steps do
    # Refuse to copy an old formula build even if its marketing version is unchanged.
    run "/usr/bin/grep", args: ["-Fxq", "5004536500ce03f8de8b8fb3b1450a52c34a22ab16a62387eb2c7c86ec8c0686",
                                "{{HOMEBREW_PREFIX}}/opt/remote2prompt/share/remote2prompt/source.sha256"]
    copy "{{HOMEBREW_PREFIX}}/opt/remote2prompt/libexec/Remote2Prompt.app",
         "Remote2Prompt.app", recursive: true
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
    This cask installs the app compiled by its companion formula, not a downloaded binary.
    Upgrade the formula from source before upgrading this cask.
    brew test realdgd/remote2prompt/remote2prompt checks the source build and the Applications copy.
    To remove all installed code: uninstall this cask, then uninstall realdgd/remote2prompt/remote2prompt.
    Use --zap on the cask uninstall to also remove this app's settings. System privacy grants are preserved.
  EOS
end
