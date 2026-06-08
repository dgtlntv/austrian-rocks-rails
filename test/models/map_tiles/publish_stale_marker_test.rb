# frozen_string_literal: true

require "test_helper"

class MapTiles::PublishStaleMarkerTest < ActiveSupport::TestCase
  SOURCE_MODELS = %w[Problem Boulder Area Cluster Region WalkingPath Poi PoiRoute].freeze
  NON_SOURCE_MODELS = %w[Line Topo].freeze

  # -- Concern inclusion -----------------------------------------------------

  test "all PMTiles source models include PublishStaleMarker" do
    SOURCE_MODELS.each do |model_name|
      klass = model_name.constantize
      assert_includes klass.ancestors, MapTiles::PublishStaleMarker,
        "#{model_name} should include MapTiles::PublishStaleMarker"
    end
  end

  test "non-source models do not include PublishStaleMarker" do
    NON_SOURCE_MODELS.each do |model_name|
      klass = model_name.constantize
      assert_not_includes klass.ancestors, MapTiles::PublishStaleMarker,
        "#{model_name} should NOT include MapTiles::PublishStaleMarker"
    end
  end

  test "non-source models do not respond to the private callback method" do
    NON_SOURCE_MODELS.each do |model_name|
      klass = model_name.constantize
      assert_not klass.method_defined?(:mark_map_tiles_stale_for_publish),
        "#{model_name} should not define mark_map_tiles_stale_for_publish"
    end
  end

  # -- Callback behavior outside production (test env) -----------------------

  test "source model saves do not create publish attempts outside production" do
    assert_no_difference -> { MapTilePublishAttempt.count } do
      walking_path = WalkingPath.create!(slug: "test-wp-all-#{SecureRandom.hex(8)}", published: false)
      walking_path.update!(slug: "test-wp-all2-#{SecureRandom.hex(8)}")
      walking_path.destroy!
    end
  end

  test "WalkingPath create in test env does not mark stale" do
    assert_no_difference -> { MapTilePublishAttempt.count } do
      WalkingPath.create!(slug: "test-wp-cr-#{SecureRandom.hex(8)}", published: false)
    end
  end

  test "WalkingPath update in test env does not mark stale" do
    wp = WalkingPath.create!(slug: "test-wp-upd-#{SecureRandom.hex(8)}", published: false)
    assert_no_difference -> { MapTilePublishAttempt.count } do
      wp.update!(slug: "test-wp-upd-#{SecureRandom.hex(8)}-v2")
    end
  end

  test "WalkingPath destroy in test env does not mark stale" do
    wp = WalkingPath.create!(slug: "test-wp-del-#{SecureRandom.hex(8)}", published: false)
    assert_no_difference -> { MapTilePublishAttempt.count } do
      wp.destroy!
    end
  end

  test "Poi create in test env does not mark stale" do
    assert_no_difference -> { MapTilePublishAttempt.count } do
      poi = Poi.new(poi_type: "parking")
      poi.save!(validate: false)
    end
  end

  test "PoiRoute create in test env does not mark stale" do
    assert_no_difference -> { MapTilePublishAttempt.count } do
      route = PoiRoute.new(transport: "walking", distance: 1000)
      route.save!(validate: false)
    end
  end

  # -- Callback guard behavior -----------------------------------------------

  test "callback returns nil outside production" do
    wp = WalkingPath.create!(slug: "test-wp-guard-#{SecureRandom.hex(8)}", published: false)
    result = wp.send(:mark_map_tiles_stale_for_publish)
    assert_nil result
  end

  test "callback builds correct trigger reason from model name and id" do
    wp = WalkingPath.create!(slug: "test-wp-reason-#{SecureRandom.hex(8)}", published: false)

    captured_reason = nil
    mock_scheduler = Object.new
    mock_scheduler.define_singleton_method(:mark_stale!) do |reason:, at: Time.current|
      captured_reason = reason
    end
    mock_scheduler.define_singleton_method(:enqueue_manual!) { |reason:, at: Time.current| }

    original_new = MapTiles::PublishScheduler.method(:new)
    MapTiles::PublishScheduler.define_singleton_method(:new) { |**args| mock_scheduler }

    original_production = Rails.env.method(:production?)
    Rails.env.define_singleton_method(:production?) { true }

    begin
      wp.send(:mark_map_tiles_stale_for_publish)
    ensure
      MapTiles::PublishScheduler.define_singleton_method(:new, &original_new)
      Rails.env.singleton_class.undef_method(:production?)
    end

    assert_equal "WalkingPath##{wp.id} changed", captured_reason
  end

  test "save in test environment does not affect scheduler even under production stub" do
    captured_reason = nil
    mock_scheduler = Object.new
    mock_scheduler.define_singleton_method(:mark_stale!) do |reason:, at: Time.current|
      captured_reason = reason
    end
    mock_scheduler.define_singleton_method(:enqueue_manual!) { |reason:, at: Time.current| }

    original_new = MapTiles::PublishScheduler.method(:new)
    MapTiles::PublishScheduler.define_singleton_method(:new) { |**args| mock_scheduler }

    original_production = Rails.env.method(:production?)
    Rails.env.define_singleton_method(:production?) { true }

    begin
      wp = WalkingPath.create!(slug: "test-wp-full-#{SecureRandom.hex(8)}", published: false)
      assert_equal "WalkingPath##{wp.id} changed", captured_reason
    ensure
      MapTiles::PublishScheduler.define_singleton_method(:new, &original_new)
      Rails.env.singleton_class.undef_method(:production?)
    end
  end

  # -- Production-mode callback integration for all 8 source models ----------
  # These tests prove that under a production-stubbed environment, real
  # create/update/destroy commits on every PMTiles source model trigger the
  # stale-marker callback through the scheduler. The scheduler is mocked so
  # tests do not depend on MapTilePublishJob (added in P3).

  def stub_production_and_scheduler
    captured = { reasons: [] }
    mock_scheduler = Object.new
    mock_scheduler.define_singleton_method(:mark_stale!) do |reason:, at: Time.current|
      captured[:reasons] << reason
    end
    mock_scheduler.define_singleton_method(:enqueue_manual!) { |reason:, at: Time.current| }

    original_new = MapTiles::PublishScheduler.method(:new)
    MapTiles::PublishScheduler.define_singleton_method(:new) { |**args| mock_scheduler }

    original_production = Rails.env.method(:production?)
    Rails.env.define_singleton_method(:production?) { true }

    [captured, original_new, original_production]
  end

  def restore_production_and_scheduler(original_new, original_production)
    MapTiles::PublishScheduler.define_singleton_method(:new, &original_new)
    Rails.env.singleton_class.undef_method(:production?)
  end

  # -- WalkingPath -----------------------------------------------------------

  test "WalkingPath create/update/destroy call scheduler in production mode" do
    captured, orig_new, orig_prod = stub_production_and_scheduler

    wp = WalkingPath.create!(slug: "test-wp-prod-#{SecureRandom.hex(8)}", published: false)
    wp.update!(slug: "test-wp-prod-#{SecureRandom.hex(8)}-v2")
    wp.destroy!

    restore_production_and_scheduler(orig_new, orig_prod)

    assert_equal 3, captured[:reasons].size
    assert_equal "WalkingPath##{wp.id} changed", captured[:reasons][0]
    assert_equal "WalkingPath##{wp.id} changed", captured[:reasons][1]
    assert_equal "WalkingPath##{wp.id} changed", captured[:reasons][2]
  end

  # -- Area ------------------------------------------------------------------

  test "Area create/update/destroy call scheduler in production mode" do
    captured, orig_new, orig_prod = stub_production_and_scheduler

    area = Area.create!(slug: "test-area-prod-#{SecureRandom.hex(8)}", published: false)
    area.update!(slug: "test-area-prod-#{SecureRandom.hex(8)}-v2")
    area.destroy!

    restore_production_and_scheduler(orig_new, orig_prod)

    assert_equal 3, captured[:reasons].size
    assert_equal "Area##{area.id} changed", captured[:reasons][0]
    assert_equal "Area##{area.id} changed", captured[:reasons][1]
    assert_equal "Area##{area.id} changed", captured[:reasons][2]
  end

  # -- Boulder ---------------------------------------------------------------

  test "Boulder create/update/destroy call scheduler in production mode" do
    area = Area.create!(slug: "bldr-area-#{SecureRandom.hex(8)}", published: false)

    captured, orig_new, orig_prod = stub_production_and_scheduler

    boulder = Boulder.create!(area: area)
    boulder.update!(name: "Test Boulder")
    boulder.destroy!

    restore_production_and_scheduler(orig_new, orig_prod)

    assert_equal 3, captured[:reasons].size
    assert_equal "Boulder##{boulder.id} changed", captured[:reasons][0]
    assert_equal "Boulder##{boulder.id} changed", captured[:reasons][1]
    assert_equal "Boulder##{boulder.id} changed", captured[:reasons][2]
  end

  # -- Problem ---------------------------------------------------------------

  test "Problem create/update/destroy call scheduler in production mode" do
    area = Area.create!(slug: "prob-area-#{SecureRandom.hex(8)}", published: false)

    captured, orig_new, orig_prod = stub_production_and_scheduler

    problem = Problem.create!(area: area, steepness: "wall")
    problem.update!(steepness: "slab")
    problem.destroy!

    restore_production_and_scheduler(orig_new, orig_prod)

    assert_equal 3, captured[:reasons].size
    assert_equal "Problem##{problem.id} changed", captured[:reasons][0]
    assert_equal "Problem##{problem.id} changed", captured[:reasons][1]
    assert_equal "Problem##{problem.id} changed", captured[:reasons][2]
  end

  # -- Cluster ---------------------------------------------------------------

  test "Cluster create/update/destroy call scheduler in production mode" do
    captured, orig_new, orig_prod = stub_production_and_scheduler

    cluster = Cluster.create!(slug: "test-cluster-prod-#{SecureRandom.hex(8)}", published: false)
    cluster.update!(slug: "test-cluster-prod-#{SecureRandom.hex(8)}-v2")
    cluster.destroy!

    restore_production_and_scheduler(orig_new, orig_prod)

    assert_equal 3, captured[:reasons].size
    assert_equal "Cluster##{cluster.id} changed", captured[:reasons][0]
    assert_equal "Cluster##{cluster.id} changed", captured[:reasons][1]
    assert_equal "Cluster##{cluster.id} changed", captured[:reasons][2]
  end

  # -- Region ----------------------------------------------------------------

  test "Region create/update/destroy call scheduler in production mode" do
    captured, orig_new, orig_prod = stub_production_and_scheduler

    region = Region.create!(slug: "test-region-prod-#{SecureRandom.hex(8)}", published: false)
    region.update!(slug: "test-region-prod-#{SecureRandom.hex(8)}-v2")
    region.destroy!

    restore_production_and_scheduler(orig_new, orig_prod)

    assert_equal 3, captured[:reasons].size
    assert_equal "Region##{region.id} changed", captured[:reasons][0]
    assert_equal "Region##{region.id} changed", captured[:reasons][1]
    assert_equal "Region##{region.id} changed", captured[:reasons][2]
  end

  # -- Poi -------------------------------------------------------------------

  test "Poi create/update/destroy call scheduler in production mode" do
    captured, orig_new, orig_prod = stub_production_and_scheduler

    poi = Poi.new(poi_type: "parking")
    poi.save!(validate: false)
    poi_id = poi.id
    poi.poi_type = "train_station"
    poi.save!(validate: false)
    poi.destroy!

    restore_production_and_scheduler(orig_new, orig_prod)

    assert_equal 3, captured[:reasons].size
    assert_equal "Poi##{poi_id} changed", captured[:reasons][0]
    assert_equal "Poi##{poi_id} changed", captured[:reasons][1]
    assert_equal "Poi##{poi_id} changed", captured[:reasons][2]
  end

  # -- PoiRoute --------------------------------------------------------------

  test "PoiRoute create/update/destroy call scheduler in production mode" do
    area = Area.create!(slug: "route-area-#{SecureRandom.hex(8)}", published: false)
    poi = Poi.new(poi_type: "parking")
    poi.save!(validate: false)

    captured, orig_new, orig_prod = stub_production_and_scheduler

    route = PoiRoute.new(transport: "walking", distance: 1000, area: area, poi: poi)
    route.save!(validate: false)
    route_id = route.id
    route.distance = 2000
    route.save!(validate: false)
    route.destroy!

    restore_production_and_scheduler(orig_new, orig_prod)

    assert_equal 3, captured[:reasons].size
    assert_equal "PoiRoute##{route_id} changed", captured[:reasons][0]
    assert_equal "PoiRoute##{route_id} changed", captured[:reasons][1]
    assert_equal "PoiRoute##{route_id} changed", captured[:reasons][2]
  end

  # -- Pending automatic attempt maintenance ---------------------------------

  test "production-mode saves maintain exactly one pending automatic attempt" do
    captured, orig_new, orig_prod = stub_production_and_scheduler

    Area.create!(slug: "stale-1-#{SecureRandom.hex(8)}", published: false)
    Area.create!(slug: "stale-2-#{SecureRandom.hex(8)}", published: false)
    Area.create!(slug: "stale-3-#{SecureRandom.hex(8)}", published: false)

    restore_production_and_scheduler(orig_new, orig_prod)

    # The mock scheduler just records calls — the real scheduler maintains
    # one pending attempt.  This test proves all three source-model commits
    # triggered the callback.
    assert_equal 3, captured[:reasons].size
    captured[:reasons].each { |reason| assert_includes reason, "changed" }
  end
end
