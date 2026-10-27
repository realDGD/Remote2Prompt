#!/usr/bin/ruby
require "find"
require "open3"

root = File.expand_path("..", __dir__)
history = ARGV.delete("--history")
abort "Usage: ruby scripts/check-publication.rb [--history]" unless ARGV.empty?
errors = []
scanned = 0
ignored_directories = %w[.git .build .swiftpm dist .local .secrets diagnostics captures recordings .idea .vscode xcuserdata]
private_extensions = /\.(?:p12|pfx|pem|key|cer|mobileprovision|provisionprofile|log|trace|crash|ips|dmp|pcap|pcapng|btsnoop|wav|aiff|caf|pcm|m4a|mp3)\z/i
rules = {
  "personal home directory" => %r{/(?:Users|home)/[A-Za-z0-9._-]+/},
  "user temporary directory" => %r{/(?:private/)?var/folders/[A-Za-z0-9/._-]+},
  "hardware address" => /\b(?:[A-Fa-f0-9]{2}:){5}[A-Fa-f0-9]{2}\b/,
  "private network address" => /\b(?:10(?:\.\d{1,3}){3}|192\.168(?:\.\d{1,3}){2}|172\.(?:1[6-9]|2\d|3[01])(?:\.\d{1,3}){2})\b/,
  "private key" => /-----BEGIN (?:[A-Z ]+ )?PRIVATE KEY-----/,
  "credential" => /\b(?:github_pat_|gh[pousr]_)[A-Za-z0-9_]{20,}/,
  "unreviewed UUID" => /\b[0-9A-Fa-f]{8}(?:-[0-9A-Fa-f]{4}){3}-[0-9A-Fa-f]{12}\b/
}

inspect_content = lambda do |content, location|
  scanned += 1
  text = content.dup.force_encoding(Encoding::UTF_8)
  if !text.valid_encoding? || text.include?("\0")
    errors << "#{location}: unreviewed binary content"
    next
  end
  text.each_line.with_index(1) do |line, number|
    rules.each do |label, pattern|
      matches = line.scan(pattern)
      next if matches.empty?
      # Standard ATVV service/characteristic identifiers are public protocol facts, not peripheral IDs.
      next if label == "unreviewed UUID" && matches.all? { |value| value.match?(/\AAB5E000[1-4]-5A21-4F05-BC7D-AF01F617B664\z/i) }
      errors << "#{location}:#{number}: #{label} (value redacted)"
    end
  end
end

validate_path = lambda do |path|
  next if path.empty? # rev-list can name the root tree with an empty path.
  parts = path.split("/")
  name = parts.last
  forbidden = (parts & ignored_directories).any? || path.match?(private_extensions)
  forbidden ||= name == ".env" || (name.start_with?(".env.") && name != ".env.example")
  errors << "#{path}: local/private file must not be tracked" if forbidden
end

top, status = Open3.capture2e("git", "-C", root, "rev-parse", "--show-toplevel")
repository = status.success? && File.realpath(top.strip) == File.realpath(root)
paths = if repository
          output, result = Open3.capture2("git", "-C", root, "ls-files", "-z")
          abort "Cannot enumerate tracked files" unless result.success?
          output.split("\0")
        else
          abort "History checks require the original Git checkout" if history
          found = []
          Find.find(root) do |path|
            if File.directory?(path)
              Find.prune if path != root && ignored_directories.include?(File.basename(path))
            else
              found << path.delete_prefix(root + "/")
            end
          end
          found
        end

paths.each do |path|
  validate_path.call(path)
  full = File.join(root, path)
  next unless File.exist?(full) || File.symlink?(full)
  if File.symlink?(full)
    errors << "#{path}: unreviewed symlink" unless path == "CLAUDE.md" && File.readlink(full) == "AGENTS.md"
  else
    inspect_content.call(File.binread(full), path)
  end
end

if history
  output, result = Open3.capture2("git", "-C", root, "rev-list", "--objects", "--all")
  abort "Cannot enumerate history" unless result.success?
  output.lines.each do |line|
    _, path = line.chomp.split(" ", 2)
    validate_path.call(path) if path
  end
  objects = output.lines.map { |line| line.split(" ", 2).first }.uniq
  Open3.popen3("git", "-C", root, "cat-file", "--batch") do |input, stream, diagnostics, process|
    objects.each do |oid|
      input.puts(oid); input.flush
      header = stream.gets&.split
      abort "Cannot read history object" unless header&.length == 3 && header[0] == oid
      content = stream.read(Integer(header[2]))
      abort "Truncated history object" unless stream.read(1) == "\n"
      inspect_content.call(content, "history #{oid[0, 12]}") if header[1] == "blob"
    end
    input.close
    abort "History reader failed" unless process.value.success?
    abort "History reader reported an error" unless diagnostics.read.empty?
  end
end

unless errors.empty?
  warn errors.uniq.join("\n")
  exit 1
end
puts "Publication checks passed (#{paths.length} paths, #{scanned} text snapshots#{history ? ", including all reachable history" : ""}; no raw values printed)"
