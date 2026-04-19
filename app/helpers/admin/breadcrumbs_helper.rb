module Admin::BreadcrumbsHelper
  def admin_region_breadcrumbs(region, active: false)
    add_breadcrumb "Regions", admin_regions_path
    if region
      if active
        add_breadcrumb region.name, nil, class: "active"
      else
        add_breadcrumb region.name, admin_region_path(region)
      end
    end
  end

  def admin_cluster_breadcrumbs(cluster, active: false)
    admin_region_breadcrumbs(cluster&.region)
    if cluster
      if active
        add_breadcrumb cluster.name, nil, class: "active"
      else
        add_breadcrumb cluster.name, admin_cluster_path(cluster)
      end
    end
  end

  def admin_area_breadcrumbs(area, active: false)
    admin_cluster_breadcrumbs(area&.cluster)
    if area
      if active
        add_breadcrumb area.name, nil, class: "active"
      else
        add_breadcrumb area.name, admin_area_problems_path(area_slug: area.slug)
      end
    end
  end
end
