# require 'vips'

namespace :app do
  task db: :environment do
    file_name = Rails.root.join("export", "app", "#{BRAND_CONFIG[:slug]}.db")
    AppDbExporter.call(file_name)
    puts "exported #{BRAND_CONFIG[:slug]}.db".green
  end

  task topos: :environment do
    area_id = ENV["area_id"]
    raise "please specify an area_id" unless area_id.present?

    puts "exporting area #{area_id}"

    Line.published.joins(:problem).where(problems: { area_id: area_id }).each do |line|
      puts "processing photo for line ##{line.id}"
      output_file = Rails.root.join("export", "app", "topos", "area-#{area_id}", "topo-#{line.topo.id}.jpg").to_s

      if File.exist?(output_file)
        puts "topo-#{line.topo.id}.jpg already exists"
      else
        # FIXME: iterate on topos (not lines) to avoid double processing
        line.topo.photo.open do |file|
          im = Vips::Image.new_from_file file.path.to_s
          im.thumbnail_image(800).write_to_file output_file
        end

        puts "created topo-#{line.topo.id}.jpg"
      end
    end
    puts "exported topos for area ##{area_id}".green
  end
end
