# frozen_string_literal: true

require "fileutils"
require "json"
require "pathname"
require "vips"
require "map_tiles/configuration"

module MapTiles
  # Packs the committed pin icon PNGs (config/map_styles/sprite) into the four
  # versioned MapLibre sprite artifacts: sprite.png + sprite.json and their @2x
  # counterparts. Only pure raster compositing happens here — the SVG sources in
  # the same directory are authoring-time inputs and are never read by the
  # pipeline, so publishing needs no SVG rasterizer.
  class SpriteBuilder
    class Error < StandardError; end

    SOURCE_DIR = "config/map_styles/sprite"
    PIXEL_RATIOS = [ 1, 2 ].freeze

    attr_reader :configuration, :source_dir

    def initialize(configuration: Configuration.new, source_dir: nil)
      @configuration = configuration
      @source_dir = Pathname(source_dir || Rails.root.join(SOURCE_DIR))
    end

    # Returns { "sprite.png" => path, "sprite.json" => path,
    #           "sprite@2x.png" => path, "sprite@2x.json" => path }.
    def build
      icons = icon_names
      raise Error, "no sprite icon PNGs found in #{source_dir}" if icons.empty?

      PIXEL_RATIOS.flat_map { |ratio| write_sheet(icons, ratio) }.to_h
    end

    private

    # Icon name = PNG basename without the @2x suffix; every name must ship
    # both pixel ratios so MapLibre clients resolve the same inventory at 1x and 2x.
    def icon_names
      ratios = Hash.new { |found, name| found[name] = [] }
      source_dir.glob("*.png").each do |path|
        name = path.basename(".png").to_s
        if name.end_with?("@2x")
          ratios[name.delete_suffix("@2x")] << 2
        else
          ratios[name] << 1
        end
      end

      ratios.keys.sort.each do |name|
        missing = PIXEL_RATIOS - ratios[name]
        raise Error, "sprite icon #{name} is missing its #{missing.map { |ratio| "#{ratio}x" }.join(', ')} PNG" if missing.any?
      end
      ratios.keys.sort
    end

    def write_sheet(icons, ratio)
      images = icons.map { |name| [ name, load_image(name, ratio) ] }
      sheet_width = images.sum { |_name, image| image.width }
      sheet_height = images.map { |_name, image| image.height }.max
      sheet = Vips::Image.black(sheet_width, sheet_height, bands: 4).copy(interpretation: :srgb)

      index = {}
      x = 0
      images.each do |name, image|
        sheet = sheet.insert(image, x, 0)
        index[name] = { "x" => x, "y" => 0, "width" => image.width, "height" => image.height, "pixelRatio" => ratio }
        x += image.width
      end

      png_path = configuration.sprite_artifact_path(suffix(ratio, ".png"))
      json_path = configuration.sprite_artifact_path(suffix(ratio, ".json"))
      FileUtils.mkdir_p(png_path.dirname)
      sheet.write_to_file(png_path.to_s)
      json_path.write(JSON.generate(index))

      [ [ "sprite#{suffix(ratio, '.png')}", png_path ], [ "sprite#{suffix(ratio, '.json')}", json_path ] ]
    end

    def load_image(name, ratio)
      path = source_dir.join("#{name}#{ratio == 2 ? '@2x' : ''}.png")
      image = Vips::Image.new_from_file(path.to_s)
      image = image.bandjoin(255) if image.bands == 3
      raise Error, "sprite icon #{path.basename} must be a 4-band RGBA PNG" unless image.bands == 4

      image
    rescue Vips::Error => e
      raise Error, "could not read sprite icon #{path.basename}: #{e.message.strip}"
    end

    def suffix(ratio, extension)
      ratio == 2 ? "@2x#{extension}" : extension
    end
  end
end
