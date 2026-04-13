class Admin::RegionMapsController < Admin::BaseController
  def show
    region = Region.find(params[:region_id])
    factory = RGeo::GeoJSON::EntityFactory.instance

    features = []

    # Create rectangle feature from region bounds
    if region.sw && region.ne
      # Create a rectangle polygon from SW and NE corners
      rectangle = FACTORY.polygon(
        FACTORY.line_string([
          FACTORY.point(region.sw.lon, region.sw.lat),  # SW corner
          FACTORY.point(region.sw.lon, region.ne.lat),  # NW corner
          FACTORY.point(region.ne.lon, region.ne.lat),  # NE corner
          FACTORY.point(region.ne.lon, region.sw.lat),  # SE corner
          FACTORY.point(region.sw.lon, region.sw.lat)   # Close (back to SW)
        ])
      )

      hash = {}.with_indifferent_access
      hash[:region_id] = region.id
      hash[:name] = region.name
      hash[:updated_at] = region.updated_at
      hash.deep_transform_keys! { |key| key.camelize(:lower) }

      features << factory.feature(rectangle, nil, hash)
    end

    feature_collection = factory.feature_collection(features)
    json = JSON.pretty_generate(RGeo::GeoJSON.encode(feature_collection))

    respond_to do |format|
      format.geojson do
        if params[:download].present?
          send_data json, filename: "region-#{region.id}-#{region.name.parameterize}.geojson", type: "application/geo+json"
        else
          render json: json
        end
      end
    end
  end
end
