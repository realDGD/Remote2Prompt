# Source-build formula; the companion cask owns the Applications bundle.
class Remote2prompt < Formula
  desc "Native macOS remote key mapping and voice-trigger app"
  homepage "https://github.com/realDGD/Remote2Prompt"
  url "https://github.com/realDGD/Remote2Prompt/archive/60dad76a2dcb8f6f5d5175676ca1c987971acd2e.tar.gz"
  version "0.1.2"
  sha256 "61d6478f36239a47738e33e257139d742fa546989bd52e295632cc64072b2804"

  depends_on macos: :sonoma

  def install
    ENV["DEVELOPER_DIR"] = "/Library/Developer/CommandLineTools"
    ENV["REMOTE2PROMPT_HOMEBREW_BUILD"] = "1"
    ENV.delete("SDKROOT")
    system "./scripts/test.sh"
    system "./scripts/build-app.sh"
    system "./scripts/verify-app.sh"
    libexec.install "dist/Remote2Prompt.app"
    (pkgshare/"source.sha256").write "61d6478f36239a47738e33e257139d742fa546989bd52e295632cc64072b2804" + "\n"
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
    assert_equal "61d6478f36239a47738e33e257139d742fa546989bd52e295632cc64072b2804", (pkgshare/"source.sha256").read.strip
    app = Pathname("/Applications/Remote2Prompt.app")
    if app.exist?
      refute_predicate app, :symlink?
      assert_match "self-check passed", shell_output("#{app}/Contents/MacOS/Remote2Prompt --self-check")
      assert_equal (libexec/"Remote2Prompt.app/Contents/MacOS/Remote2Prompt").binread,
                   (app/"Contents/MacOS/Remote2Prompt").binread
    end
  end
end
