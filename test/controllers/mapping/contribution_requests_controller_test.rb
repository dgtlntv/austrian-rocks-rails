# frozen_string_literal: true

require "test_helper"

class Mapping::ContributionRequestsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @area = Area.create!(name: "Contribution Area", slug: "contribution-area", published: true)
    @shared_location = point(16.3, 47.3)
    @open_problem = create_problem(name: "Open Problem", grade: "6b", ascents: 12)
    @second_open_problem = create_problem(name: "Second Problem", grade: "7a", ascents: 3)
    @closed_problem = create_problem(name: "Closed Problem", grade: "5a", ascents: 20)

    ContributionRequest.create!(problem: @open_problem, what: "location", state: "open", location_estimated: @shared_location)
    ContributionRequest.create!(problem: @second_open_problem, what: "location", state: "open", location_estimated: @shared_location)
    ContributionRequest.create!(problem: @closed_problem, what: "location", state: "closed", location_estimated: point(16.4, 47.4))
  end

  test "geojson contains grouped open contribution request markers" do
    get "/en/mapping/requests.geojson"

    assert_response :success
    body = JSON.parse(response.body)
    features = body.fetch("features")

    assert_equal 1, features.size
    properties = features.first.fetch("properties")
    assert_equal "Open Problem + 1", properties.fetch("name")
    assert_equal "", properties.fetch("nameEn")

    problems = properties.fetch("problems")
    assert_equal [ @open_problem.id, @second_open_problem.id ], problems.map { |problem| problem.fetch("id") }
    assert_equal [ "6b", "7a" ], problems.map { |problem| problem.fetch("grade") }
    assert_equal [ 12, 3 ], problems.map { |problem| problem.fetch("ascents") }
    assert problems.all? { |problem| problem.key?("name") }
    assert_not_includes problems.map { |problem| problem.fetch("id") }, @closed_problem.id
  end

  private

  def create_problem(attributes)
    Problem.create!({ area: @area, steepness: "wall", location: point(16.2, 47.2) }.merge(attributes))
  end

  def point(lon, lat)
    FACTORY.point(lon, lat)
  end
end
