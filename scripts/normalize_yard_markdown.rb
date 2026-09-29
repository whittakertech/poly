# frozen_string_literal: true

require 'find'

root = ARGV[0] || 'docs/api'
unless Dir.exist?(root)
  warn "normalize_yard_markdown: directory not found: #{root}"
  exit 0
end

files = []
Find.find(root) do |path|
  files << path if File.file?(path) && File.extname(path) == '.md'
end

files.each do |file|
  lines = File.readlines(file, chomp: true)
  output = []
  in_fence = false

  lines.each do |line|
    if line.strip.start_with?('```')
      in_fence = !in_fence
      output << line
      next
    end

    starts_list_item = line.match?(/^(\*\s{3}|-\s)/)

    if starts_list_item && !in_fence
      previous = output.last
      previous_is_nonblank = previous && !previous.strip.empty?
      previous_is_list = previous&.match?(/^(\*\s{3}|-\s)/)
      previous_is_code_indent = previous&.start_with?('    ')

      output << '' if previous_is_nonblank && !previous_is_list && !previous_is_code_indent
    end

    output << line
  end

  normalized = output.join("\n")
  normalized << "\n" unless normalized.end_with?("\n")
  File.write(file, normalized)
end

puts "normalize_yard_markdown: processed #{files.length} files under #{root}"
