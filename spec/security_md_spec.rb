# frozen_string_literal: true

require 'yaml'
require 'date'

# rubocop:disable RSpec/DescribeClass
RSpec.describe 'SECURITY.md' do
  let(:path) { File.expand_path('../SECURITY.md', __dir__) }
  let(:text) { File.read(path) }
  let(:frontmatter) do
    match = text.match(/\A---\n(.*?)\n---\n/m)
    raise 'SECURITY.md has no YAML frontmatter at the start' unless match

    YAML.safe_load(match[1], permitted_classes: [Date])
  end
  let(:versions) { frontmatter['versions'] }

  it 'exists at the repository root' do
    expect(File.exist?(path)).to be(true)
  end

  it 'has a versions mapping' do
    expect(versions).to be_a(Hash)
  end

  it 'uses only string version keys' do
    expect(versions.keys).to all(be_a(String))
  end

  it 'uses only allowed support values and known fields' do
    versions.each_value do |entry|
      expect(entry['support']).to eq('full').or(eq('security')).or(eq('none'))
      expect(entry.keys - %w[support eol]).to be_empty
    end
  end

  it 'uses ISO 8601 EOL dates when present' do
    versions.each_value do |entry|
      next unless entry.key?('eol')

      expect(entry['eol'].to_s).to match(/\A\d{4}-\d{2}-\d{2}\z/)
      expect { Date.iso8601(entry['eol'].to_s) }.not_to raise_error
    end
  end

  it 'lists every declared version line in the Markdown table' do
    versions.each_key do |line|
      expect(text).to match(/^\|\s*#{Regexp.escape(line)}(\.x)?\s*\|/)
    end
  end
end
# rubocop:enable RSpec/DescribeClass
