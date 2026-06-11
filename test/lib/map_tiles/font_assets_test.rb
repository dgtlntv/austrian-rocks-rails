# frozen_string_literal: true

require "test_helper"

class MapTiles::FontAssetsTest < ActiveSupport::TestCase
  APPROVED_INTER_FONT_STACKS = [
    "Inter Light",
    "Inter Regular",
    "Inter Medium",
    "Inter Bold",
    "Inter Medium Italic",
    "Inter Bold Italic"
  ].freeze

  SOURCE_FONT_EXTENSIONS = %w[.ttf .otf .woff .woff2].freeze

  test "committed Inter v1 glyph tree contains only approved runtime assets" do
    root = Rails.root.join("config/map_styles/fonts/inter-v1")

    assert_predicate root, :directory?
    assert_equal (APPROVED_INTER_FONT_STACKS + %w[LICENSE.md README.md]).sort, root.children.map { |child| child.basename.to_s }.sort

    APPROVED_INTER_FONT_STACKS.each do |font_stack|
      stack_root = root.join(font_stack)
      pbf_files = stack_root.children.select { |child| child.extname == ".pbf" }

      assert_predicate stack_root, :directory?
      assert_predicate stack_root.join("0-255.pbf"), :file?
      assert pbf_files.any?, "expected #{font_stack} to include PBF glyph ranges"
      assert_empty stack_root.children.reject { |child| child.file? && child.extname == ".pbf" }
    end

    source_font_files = Dir.glob(root.join("**/*")).map { |path| Pathname(path) }.select { |path| path.file? && SOURCE_FONT_EXTENSIONS.include?(path.extname.downcase) }
    assert_empty source_font_files
  end

  test "Inter v1 glyph documentation records provenance license and update rule" do
    root = Rails.root.join("config/map_styles/fonts/inter-v1")
    readme = root.join("README.md")
    license = root.join("LICENSE.md")

    assert_predicate readme, :file?
    assert_predicate license, :file?

    documentation = [ readme.read, license.read ].join("\n")
    assert_includes documentation, "SIL Open Font License 1.1"
    assert_includes documentation, "tmp/font-maker-2026-06-11T14_25_38.391Z"
    assert_includes documentation, "inter-v2"
    assert_includes documentation, "map_styles/fonts/inter-v1/{fontstack}/{range}.pbf"
  end
end
