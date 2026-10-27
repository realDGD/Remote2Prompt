#!/usr/bin/ruby
require "find"
require "pathname"
require "uri"

root = File.expand_path("..", __dir__)
errors = []
files = []
Find.find(root) do |path|
  if File.directory?(path)
    Find.prune if %w[.git .build .swiftpm dist].include?(File.basename(path))
  elsif File.file?(path)
    files << path
  end
end

files.each do |path|
  next unless path.match?(/\.(md|swift|sh|rb|in|plist)\z/) || %w[Makefile VERSION .gitignore].include?(File.basename(path))
  content = File.read(path, encoding: "UTF-8")
  relative = Pathname.new(path).relative_path_from(Pathname.new(root)).to_s
  errors << "#{relative}: file must end with exactly one newline" unless content.end_with?("\n") && !content.end_with?("\n\n")
  errors << "#{relative}: trailing whitespace" if content.match?(/[ \t]+$/)
  next unless path.end_with?(".md")

  unless relative.start_with?(".agents/notes/archived/")
    content.scan(/\[[^\]]+\]\(([^\s)]+)\)/).flatten.each do |link|
      next if link.match?(/\A(?:[a-z][a-z0-9+.-]*:|#)/i)
      target = URI::DEFAULT_PARSER.unescape(link.split("#", 2).first)
      errors << "#{relative}: missing link target #{target}" unless File.exist?(File.expand_path(target, File.dirname(path)))
    end
  end

  next unless relative.start_with?(".agents/notes/") && File.basename(path) != "README.md"
  match = relative.match(%r{\A\.agents/notes/(proposed|implemented|rejected|archived)/(feature|bug-fix|simplification|architecture|process|testing)/\d{4}-\d{2}-\d{2}-[a-z0-9-]+\.md\z})
  unless match
    errors << "#{relative}: invalid Agent Note lifecycle/class/name"
    next
  end
  lifecycle = match[1]
  status = lifecycle == "archived" ? "implemented" : lifecycle
  lines = content.lines.map(&:chomp)
  valid_spacing = if lifecycle == "archived"
                    lines[3]&.match?(/\AArchived: \d{4}-\d{2}-\d{2}\z/) && lines[4] == ""
                  else
                    lines[3] == ""
                  end
  errors << "#{relative}: invalid title or header spacing" unless lines[0]&.start_with?("# Agent Note: ") && lines[1] == "" && valid_spacing
  valid_status = status == "rejected" ? lines[2]&.match?(/\AStatus: rejected — .+\z/) : lines[2] == "Status: #{status}"
  errors << "#{relative}: status disagrees with lifecycle" unless valid_status
  # Frozen archive content has no current-link or body-format maintenance requirement.
  next if lifecycle == "archived"
  headings = content.scan(/^## (.+)$/).flatten
  errors << "#{relative}: body must start with Problem" unless headings.first == "Problem"
  required = case lifecycle
             when "implemented" then ["Problem", "Decision", "Alternatives considered", "Consequences"]
             when "proposed" then ["Problem", "Proposal", "Alternatives considered", "Acceptance criteria", "Risks"]
             else ["Problem", "Proposal", "Alternatives considered"]
             end
  required.each { |heading| errors << "#{relative}: missing #{heading}" unless headings.include?(heading) }
  if lifecycle == "implemented" && (headings & ["Proposal", "Plan", "Migration plan", "Acceptance criteria"]).any?
    errors << "#{relative}: implemented Note still contains proposal sections"
  end
end

claude = File.join(root, "CLAUDE.md")
errors << "CLAUDE.md must symlink AGENTS.md" unless File.symlink?(claude) && File.readlink(claude) == "AGENTS.md"
unless errors.empty?
  warn errors.join("\n")
  exit 1
end
puts "Repository checks passed (#{files.count { |f| f.end_with?(".md") }} Markdown files)"
