cask "remote2prompt-app" do
  version "0.1.2"
  sha256 "0ea4992a42beb5e96fcfd70af981f169946b93025923ed0b9867abf9e9753a7a"

  url "https://github.com/realDGD/Remote2Prompt/archive/a1ca490dbdb112d70b34bb74610b03ca869ba9f4.tar.gz"
  name "Remote2Prompt"
  desc "Native macOS remote key mapping and voice-trigger app built from source"
  homepage "https://github.com/realDGD/Remote2Prompt"

  depends_on formula: "realdgd/remote2prompt/remote2prompt"
  depends_on macos: :sonoma

  app "Remote2Prompt.app"

  preflight_steps do
    # Refuse to copy an old formula build even if its marketing version is unchanged.
    run "/usr/bin/grep", args: ["-Fxq", "0ea4992a42beb5e96fcfd70af981f169946b93025923ed0b9867abf9e9753a7a",
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
