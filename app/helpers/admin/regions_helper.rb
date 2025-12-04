module Admin::RegionsHelper
  def geojson_io_url(region)
    "http://geojson.io/#data=data:text/x-url," +
      URI.encode_www_form_component(geojson_source_url(region, prod_url: true))
  end

  def geojson_source_url(region, download: false, prod_url: false)
    args = { download: download.presence }
    args.merge!(host: BRAND_CONFIG[:domains][:www], port: nil, protocol: "https") if prod_url
    admin_region_map_url(region_id: region.id, format: :geojson, **args)
  end
end
