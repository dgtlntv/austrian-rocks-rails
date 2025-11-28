module Admin::ClustersHelper
  def geojson_io_url(cluster)
    "http://geojson.io/#data=data:text/x-url," +
      URI.encode_www_form_component(geojson_source_url(cluster, prod_url: true))
  end

  def geojson_source_url(cluster, download: false, prod_url: false)
    args = { download: download.presence }
    args.merge!(host: BRAND_CONFIG[:domains][:www], port: nil, protocol: "https") if prod_url
    admin_cluster_map_url(cluster_id: cluster.id, format: :geojson, **args)
  end
end
