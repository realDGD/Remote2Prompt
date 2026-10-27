#!/usr/bin/ruby
require "digest"
require "fileutils"
require "tmpdir"
require "uri"

root = File.expand_path("..", __dir__)
version = File.read(File.join(root, "VERSION")).strip
abort "VERSION must be numeric major.minor.patch" unless version.match?(/\A\d+\.\d+\.\d+\z/)
output = File.join(root, "dist", "homebrew")
FileUtils.mkdir_p(output)

# Keep local outputs and environment files out of the source archive.
entries = %w[Package.swift VERSION Makefile README.md AGENTS.md CLAUDE.md THIRD_PARTY_NOTICES.md .gitignore Sources Tests Resources scripts packaging docs .agents .github]
entries << "LICENSE" if File.file?(File.join(root, "LICENSE"))
archive = nil
checksum = nil
Dir.mktmpdir("remote2prompt-archive-") do |temporary|
  pending = File.join(temporary, "source.tar.gz")
  success = system(
    "/usr/bin/tar", "-czf", pending,
    "--exclude=.DS_Store", "--exclude=.git", "--exclude=.build", "--exclude=dist",
    "--exclude=.env", "--exclude=.env.*", "-C", root, *entries
  )
  abort "Source archive failed" unless success
  checksum = Digest::SHA256.file(pending).hexdigest
  archive = File.join(output, "remote2prompt-#{version}-#{checksum[0, 12]}.tar.gz")
  FileUtils.mv(pending, archive)
end

tap = File.join(output, "tap")
FileUtils.mkdir_p(File.join(tap, "Formula"))
template = File.read(File.join(root, "packaging", "homebrew", "remote2prompt.rb.in"))
url = "file://#{URI::DEFAULT_PARSER.escape(archive)}"
formula = template.gsub("@SOURCE_URL@", url.dump).gsub("@VERSION@", version.dump).gsub("@SHA256@", checksum.dump)
File.write(File.join(tap, "Formula", "remote2prompt.rb"), formula)
abort "Formula syntax check failed" unless system("/usr/bin/ruby", "-c", File.join(tap, "Formula", "remote2prompt.rb"))
unless File.directory?(File.join(tap, ".git"))
  abort "Tap initialization failed" unless system("/usr/bin/git", "init", "--quiet", "--initial-branch=main", tap)
end
abort "Tap staging failed" unless system("/usr/bin/git", "-C", tap, "add", "Formula/remote2prompt.rb")
unless system("/usr/bin/git", "-C", tap, "diff", "--cached", "--quiet")
  abort "Tap commit failed" unless system(
    "/usr/bin/git", "-C", tap,
    "-c", "user.name=Remote2Prompt local packaging", "-c", "user.email=local@remote2prompt.invalid",
    "-c", "commit.gpgsign=false", "-c", "core.hooksPath=/dev/null",
    "commit", "--quiet", "-m", "Package local Remote2Prompt #{version}"
  )
end
puts "Source: #{archive}"
puts "SHA256: #{checksum}"
puts "Local tap: #{tap}"
puts "Next: brew tap --custom-remote remote2prompt/local \"#{tap}\""
puts "Then: brew install --build-from-source remote2prompt/local/remote2prompt"
