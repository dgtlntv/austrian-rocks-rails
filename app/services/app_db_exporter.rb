class AppDbExporter
  def self.call(file_path)
    new(file_path).call
  end

  def initialize(file_path)
    @file_path = file_path
  end

  def call
    FileUtils.mkdir_p(File.dirname(@file_path))
    File.delete(@file_path) if File.exist?(@file_path)

    db = SQLite3::Database.new(@file_path)

    create_problems_table(db)
    insert_problems(db)

    create_areas_table(db)
    insert_areas(db)

    create_clusters_table(db)
    insert_clusters(db)

    create_regions_table(db)
    insert_regions(db)

    create_pois_table(db)
    insert_pois(db)

    create_poi_routes_table(db)
    insert_poi_routes(db)

    create_lines_table(db)
    insert_lines(db)

    @file_path
  ensure
    db.close if db
  end

  private

  def create_problems_table(db)
    db.execute <<-SQL
      create table problems (
        id INTEGER NOT NULL PRIMARY KEY,
        name TEXT,
        name_en TEXT,
        name_searchable TEXT,
        grade TEXT,
        latitude REAL NOT NULL,
        longitude REAL NOT NULL,
        steepness TEXT NOT NULL,
        sit_start INTEGER NOT NULL,
        area_id INTEGER NOT NULL,
        featured INTEGER NOT NULL,
        popularity INTEGER,
        parent_id INTEGER,
        description TEXT,
        video_links TEXT
      );
      CREATE INDEX problem_idx ON problems(id);
      CREATE INDEX problem_area_idx ON problems(area_id);
      CREATE INDEX problem_grade_idx ON problems(grade);
    SQL
  end

  def insert_problems(db)
    Problem.with_location.joins(:area).where(area: { published: true }).find_each do |p|
      db.execute(
        "INSERT INTO problems (id, name, name_en, name_searchable, grade, latitude, longitude,
        steepness, sit_start, area_id,
        featured, popularity, parent_id, description, video_links)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)",
        [ p.id,
          I18n.with_locale(:de) { p.name_with_fallback },
          I18n.with_locale(:en) { p.name_with_fallback },
          normalize(p.name),
          p.grade, p.location&.lat, p.location&.lon,
          p.steepness, p.sit_start ? 1 : 0, p.area_id,
          p.featured ? 1 : 0, p.popularity, p.parent_id,
          p.description.presence, p.video_links&.join(",").presence ]
      )
    end
  end

  def create_areas_table(db)
    db.execute <<-SQL
      create table areas (
        id INTEGER NOT NULL PRIMARY KEY,
        name TEXT NOT NULL,
        name_searchable TEXT NOT NULL,
        priority INTEGER NOT NULL,
        description_de TEXT,
        description_en TEXT,
        warning_de TEXT,
        warning_en TEXT,
        tags TEXT,
        south_west_lat REAL NOT NULL,
        south_west_lon REAL NOT NULL,
        north_east_lat REAL NOT NULL,
        north_east_lon REAL NOT NULL,
        level1_count INTEGER NOT NULL,
        level2_count INTEGER NOT NULL,
        level3_count INTEGER NOT NULL,
        level4_count INTEGER NOT NULL,
        level5_count INTEGER NOT NULL,
        level6_count INTEGER NOT NULL,
        level7_count INTEGER NOT NULL,
        level8_count INTEGER NOT NULL,
        problems_count INTEGER NOT NULL,
        cluster_id INTEGER,
        download_size REAL NOT NULL
      );
      CREATE INDEX area_idx ON areas(id);
    SQL
  end

  def insert_areas(db)
    Area.published.each do |a|
      db.execute(
        "INSERT INTO areas (id, name, name_searchable, priority, description_de, description_en, warning_de, warning_en, tags, south_west_lat, south_west_lon, north_east_lat, north_east_lon,
                            level1_count, level2_count, level3_count, level4_count, level5_count, level6_count, level7_count, level8_count, problems_count, cluster_id, download_size)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)",
        [
          a.id,
          a.name,
          normalize(a.name),
          a.priority,
          a.description_de.presence, a.description_en.presence,
          a.warning_de.presence, a.warning_en.presence,
          a.tags.join(",").presence,
          a.bounds[:south_west]&.lat, a.bounds[:south_west]&.lon, a.bounds[:north_east]&.lat, a.bounds[:north_east]&.lon,
          a.problems.with_location.level(1).count, a.problems.with_location.level(2).count, a.problems.with_location.level(3).count, a.problems.with_location.level(4).count,
          a.problems.with_location.level(5).count, a.problems.with_location.level(6).count, a.problems.with_location.level(7).count, a.problems.with_location.level(8).count,
          a.problems.with_location.count,
          a.cluster_id,
          a.download_size
        ]
      )
    end
  end

  def create_clusters_table(db)
    db.execute <<-SQL
      create table clusters (
        id INTEGER NOT NULL PRIMARY KEY,
        name TEXT NOT NULL,
        main_area_id INTEGER NOT NULL,
        region_id INTEGER,
        slug TEXT,
        tags TEXT,
        published INTEGER
      );
      CREATE INDEX cluster_idx ON clusters(id);
    SQL
  end

  def insert_clusters(db)
    Cluster.all.each do |c|
      db.execute(
        "INSERT INTO clusters (id, name, main_area_id, region_id, slug, tags, published)
        VALUES (?, ?, ?, ?, ?, ?, ?)",
        [
          c.id,
          c.name,
          c.main_area_id,
          c.region_id,
          c.slug,
          c.tags.join(",").presence,
          c.published ? 1 : 0
        ]
      )
    end
  end

  def create_regions_table(db)
    db.execute <<-SQL
      create table regions (
        id INTEGER PRIMARY KEY,
        name TEXT,
        slug TEXT,
        main_cluster_id INTEGER,
        center_lat REAL,
        center_lon REAL,
        south_west_lat REAL,
        south_west_lon REAL,
        north_east_lat REAL,
        north_east_lon REAL,
        tags TEXT,
        published INTEGER
      );
      CREATE INDEX region_idx ON regions(id);
    SQL
  end

  def insert_regions(db)
    Region.all.each do |r|
      db.execute(
        "INSERT INTO regions (id, name, slug, main_cluster_id, center_lat, center_lon, south_west_lat, south_west_lon, north_east_lat, north_east_lon, tags, published)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)",
        [
          r.id,
          r.name,
          r.slug,
          r.main_cluster_id,
          r.center&.lat,
          r.center&.lon,
          r.sw&.lat,
          r.sw&.lon,
          r.ne&.lat,
          r.ne&.lon,
          r.tags.join(",").presence,
          r.published ? 1 : 0
        ]
      )
    end
  end

  def create_pois_table(db)
    db.execute <<-SQL
      create table pois (
        id INTEGER NOT NULL PRIMARY KEY,
        poi_type TEXT NOT NULL,
        name TEXT NOT NULL,
        short_name TEXT NOT NULL,
        google_url TEXT NOT NULL,
        latitude REAL NOT NULL,
        longitude REAL NOT NULL
      );
      CREATE INDEX poi_idx ON pois(id);
    SQL
  end

  def insert_pois(db)
    Poi.all.each do |p|
      db.execute(
        "INSERT INTO pois (id, poi_type, name, short_name, google_url, latitude, longitude)
        VALUES (?, ?, ?, ?, ?, ?, ?)",
        [ p.id, p.poi_type, p.name, p.short_name, p.google_url, p.location&.lat, p.location&.lon ]
      )
    end
  end

  def create_poi_routes_table(db)
    db.execute <<-SQL
      create table poi_routes (
        id INTEGER NOT NULL PRIMARY KEY,
        area_id INTEGER NOT NULL,
        poi_id INTEGER NOT NULL,
        distance_in_minutes INTEGER NOT NULL,
        transport TEXT NOT NULL
      );
      CREATE INDEX poi_route_idx ON poi_routes(id);
      CREATE INDEX poi_route_area_idx ON poi_routes(area_id);
      CREATE INDEX poi_route_poi_idx ON poi_routes(poi_id);
    SQL
  end

  def insert_poi_routes(db)
    PoiRoute.all.each do |pr|
      db.execute(
        "INSERT INTO poi_routes (id, area_id, poi_id, distance_in_minutes, transport)
        VALUES (?, ?, ?, ?, ?)",
        [ pr.id, pr.area_id, pr.poi_id, pr.distance_in_minutes, pr.transport ]
      )
    end
  end

  def create_lines_table(db)
    db.execute <<-SQL
      create table lines (
        id INTEGER NOT NULL PRIMARY KEY,
        problem_id INTEGER NOT NULL,
        topo_id INTEGER NOT NULL,
        coordinates TEXT
      );
      CREATE INDEX line_idx ON lines(id);
      CREATE INDEX line_problem_idx ON lines(problem_id);
      CREATE INDEX line_topo_idx ON lines(topo_id);
    SQL
  end

  def insert_lines(db)
    Line.joins(problem: :area).joins(:topo).where(area: { published: true }, topo: { published: true }).find_each do |l|
      db.execute(
        "INSERT INTO lines (id, problem_id, topo_id, coordinates)
        VALUES (?, ?, ?, ?)",
        [ l.id, l.problem_id, l.topo_id, l.coordinates.to_json ]
      )
    end
  end

  def normalize(string)
    return nil if string.nil?
    I18n.with_locale(:de) { I18n.transliterate(string) }.gsub(/[^0-9a-zA-Z]/, "")&.downcase
  end
end
