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

    # Temporarily replace PublishScheduler.new
    original_new = MapTiles::PublishScheduler.method(:new)
    MapTiles::PublishScheduler.define_singleton_method(:new) { |**args| mock_scheduler }

    # Temporarily make production? return true
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
end
