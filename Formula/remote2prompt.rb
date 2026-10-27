# Source-build formula; the companion cask owns the Applications bundle.
class Remote2prompt < Formula
  desc "Native macOS remote key mapping and voice-trigger app"
  homepage "https://github.com/realDGD/Remote2Prompt"
  url "https://github.com/realDGD/Remote2Prompt/archive/1f91c0e0defa05896e4dea356df007160fb8d700.tar.gz"
  version "0.2.1"
  sha256 "5004536500ce03f8de8b8fb3b1450a52c34a22ab16a62387eb2c7c86ec8c0686"

  depends_on macos: :sonoma

  def install
    ENV["DEVELOPER_DIR"] = "/Library/Developer/CommandLineTools"
    ENV["REMOTE2PROMPT_HOMEBREW_BUILD"] = "1"
    ENV.delete("SDKROOT")
    system "./scripts/test.sh"
    system "./scripts/build-app.sh"
    system "./scripts/verify-app.sh"
    libexec.install "dist/Remote2Prompt.app"
    (pkgshare/"source.sha256").write "5004536500ce03f8de8b8fb3b1450a52c34a22ab16a62387eb2c7c86ec8c0686" + "\n"
    (bin/"remote2prompt").write <<~SH
      #!/bin/sh
      if [ "$#" -eq 0 ]; then
        if /usr/bin/cmp -s /Applications/Remote2Prompt.app/Contents/MacOS/Remote2Prompt "#{libexec}/Remote2Prompt.app/Contents/MacOS/Remote2Prompt"; then
          exec /usr/bin/open /Applications/Remote2Prompt.app
        fi
        exec /usr/bin/open "#{libexec}/Remote2Prompt.app"
      fi
      exec "#{libexec}/Remote2Prompt.app/Contents/MacOS/Remote2Prompt" "$@"
    SH
  end

  def caveats
    <<~EOS
      Remote key mapping and voice audio are development previews; real remote acceptance is pending.
      Run remote2prompt to open settings. No audio driver is installed.
      Install the built app into Applications with:
        brew install --cask realdgd/remote2prompt/remote2prompt-app
      Remove the app with brew uninstall --cask realdgd/remote2prompt/remote2prompt-app.
      Add --zap to remove its preferences; uninstall this formula to remove the source-build files and launcher.
    EOS
  end

  test do
    assert_match "self-check passed", shell_output("#{bin}/remote2prompt --self-check")
    assert_match version.to_s, shell_output("#{bin}/remote2prompt --version")
    assert_equal "5004536500ce03f8de8b8fb3b1450a52c34a22ab16a62387eb2c7c86ec8c0686", (pkgshare/"source.sha256").read.strip
    app = Pathname("/Applications/Remote2Prompt.app")
    if app.exist?
      refute_predicate app, :symlink?
      assert_match "self-check passed", shell_output("#{app}/Contents/MacOS/Remote2Prompt --self-check")
      assert_equal (libexec/"Remote2Prompt.app/Contents/MacOS/Remote2Prompt").binread,
                   (app/"Contents/MacOS/Remote2Prompt").binread
    end
  end
end
