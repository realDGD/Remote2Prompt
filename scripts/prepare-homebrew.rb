#!/usr/bin/ruby
require "digest"
require "fileutils"
require "open3"
require "optparse"
require "tmpdir"
require "uri"

root = File.expand_path("..", __dir__)
options = { tap: "remote2prompt/local" }
OptionParser.new do |parser|
  parser.banner = "Usage: prepare-homebrew.rb [--remote FULL_COMMIT --tap OWNER/NAME]"
  parser.on("--remote COMMIT", "Pin a public GitHub source archive to this full commit") { |value| options[:ref] = value }
  parser.on("--tap NAME", "Source Cask tap name") { |value| options[:tap] = value }
end.parse!
abort "Unexpected arguments" unless ARGV.empty?
abort "Invalid tap name" unless options[:tap].match?(%r{\A[a-z0-9-]+/[a-z0-9-]+\z})
if options[:ref]
  abort "Remote source requires a full commit SHA" unless options[:ref].match?(/\A[0-9a-f]{40}\z/)
  head, status = Open3.capture2("git", "-C", root, "rev-parse", "HEAD")
  abort "Remote source must be current HEAD" unless status.success? && head.strip == options[:ref]
  changes, status = Open3.capture2("git", "-C", root, "status", "--porcelain")
  abort "Commit source and templates before generating the public tap" unless status.success? && changes.empty?
end
version = File.read(File.join(root, "VERSION")).strip
abort "VERSION must be numeric major.minor.patch" unless version.match?(/\A\d+\.\d+\.\d+\z/)
output = File.join(root, "dist", options[:ref] ? "homebrew-remote" : "homebrew")
FileUtils.mkdir_p(output)

# Keep local outputs and environment files out of the source archive.
entries = %w[Package.swift VERSION Makefile README.md AGENTS.md CLAUDE.md THIRD_PARTY_NOTICES.md .gitignore Sources Tests Resources scripts packaging docs .agents .github]
entries << "LICENSE" if File.file?(File.join(root, "LICENSE"))
%w[Formula Casks].each { |entry| entries << entry if File.directory?(File.join(root, entry)) }
archive = nil
checksum = nil
Dir.mktmpdir("remote2prompt-archive-") do |temporary|
  pending = File.join(temporary, "source.tar.gz")
  if options[:ref]
    url = "https://github.com/realDGD/Remote2Prompt/archive/#{options[:ref]}.tar.gz"
    success = system("/usr/bin/curl", "--fail", "--location", "--retry", "3", "--silent", "--show-error", url, "--output", pending)
  else
    success = system(
      "/usr/bin/tar", "-czf", pending,
      "--exclude=.DS_Store", "--exclude=.git", "--exclude=.build", "--exclude=dist",
      "--exclude=.env", "--exclude=.env.*", "-C", root, *entries
    )
  end
  abort "Source archive failed" unless success
  checksum = Digest::SHA256.file(pending).hexdigest
  archive = File.join(output, "remote2prompt-#{version}-#{checksum[0, 12]}.tar.gz")
  FileUtils.mv(pending, archive)
end

tap = File.join(output, "tap")
FileUtils.mkdir_p(File.join(tap, "Casks"))
FileUtils.rm_rf(File.join(tap, "Formula"))
FileUtils.rm_f(File.join(tap, "Casks", "remote2prompt-app.rb"))
url = options[:ref] ? "https://github.com/realDGD/Remote2Prompt/archive/#{options[:ref]}.tar.gz" : "file://#{URI::DEFAULT_PARSER.escape(archive)}"
head, result = Open3.capture2("git", "-C", root, "rev-parse", "HEAD")
abort "Cannot identify source commit" unless result.success? && head.strip.match?(/\A[0-9a-f]{40}\z/)
source_commit = options[:ref] || head.strip
source_root = options[:ref] ? "Remote2Prompt-#{options[:ref]}" : "."
template = File.read(File.join(root, "packaging", "homebrew", "remote2prompt.rb.in"))
rendered = template.gsub("@SOURCE_URL@", url.dump).gsub("@VERSION@", version.dump)
                   .gsub("@SHA256@", checksum.dump).gsub("@TAP@", options[:tap])
                   .gsub("@SOURCE_COMMIT@", source_commit.dump).gsub("@SOURCE_ROOT@", source_root)
target = File.join(tap, "Casks", "remote2prompt.rb")
File.write(target, rendered)
abort "Ruby syntax check failed" unless system("/usr/bin/ruby", "-c", target)
File.write(File.join(tap, ".gitignore"), ".DS_Store\n.build/\n*.log\n")
readme = <<~MD
  # Remote2Prompt source tap

  [Source](https://github.com/realDGD/Remote2Prompt), macOS 14+, Swift 6 Command Line Tools. No Xcode or local signing certificate is required.

  ```sh
  brew tap realdgd/remote2prompt https://github.com/realDGD/Remote2Prompt.git
  brew install --cask realdgd/remote2prompt/remote2prompt
  remote2prompt --self-check
  ```

  The single cask compiles a fixed source archive, moves the app into Applications and removes its build cache. No companion formula or driver is installed. This generated directory is a packaging preview; installation tests must use the published HTTPS tap, never this checkout or its file URL.

  ```sh
  brew uninstall --cask --zap realdgd/remote2prompt/remote2prompt
  ```

  `--zap` removes only this app's settings and caches; omit it to retain settings. macOS privacy grants and audio drivers are untouched. Source code is public; a project license has not yet been selected.
MD
File.write(File.join(tap, "README.md"), readme)
# Generated taps are packaging previews; the source repository owns CI.
FileUtils.rm_rf(File.join(tap, ".github"))
unless File.directory?(File.join(tap, ".git"))
  abort "Tap initialization failed" unless system("/usr/bin/git", "init", "--quiet", "--initial-branch=main", tap)
end
abort "Tap staging failed" unless system("/usr/bin/git", "-C", tap, "add", "--all")
unless system("/usr/bin/git", "-C", tap, "diff", "--cached", "--quiet")
  abort "Tap commit failed" unless system(
    "/usr/bin/git", "-C", tap,
    "-c", "user.name=Remote2Prompt local packaging", "-c", "user.email=local@remote2prompt.invalid",
    "-c", "commit.gpgsign=false", "-c", "core.hooksPath=/dev/null",
    "commit", "--quiet", "-m", "Package Remote2Prompt #{version}#{options[:ref] ? " from " + options[:ref][0, 12] : " locally"}"
  )
end
puts "Source: #{archive}"
puts "SHA256: #{checksum}"
puts "Generated tap: #{tap}"
puts "Validate installations only through the published HTTPS tap, not this generated checkout."
