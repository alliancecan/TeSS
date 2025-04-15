require 'test_helper'

class AcenetLearnWorldsIngestorTest < ActiveSupport::TestCase
  setup do
    @user = users(:regular_user)
    @content_provider = content_providers(:acenet)
    mock_ingestions
    mock_timezone # System time zone should not affect test result
  end

  teardown do
    reset_timezone
  end

  test 'can ingest events from Acenet LearnWorlds' do
    source = @content_provider.sources.build(
      url: 'https://www.acenet.training',
      method: 'acenet_learn_worlds',
      token: '{"client_id" : "REDACTED", "access_token" : "REDACTED"}',
      enabled: true
    )

    ingestor = Ingestors::AcenetLearnWorldsIngestor.new

    # Check events doesn't already exist
    new_events =
      [{title: "Foundations of Machine Learning",
        url: "https://www.acenet.training/course/basics-of-machine-learning"},
       {title: "Introductory Programming with Python (part 1 of 2)",
        url: "https://www.acenet.training/course/introduction-to-python-programming"},
       {title: "Introductory Programming with Python (part 2 of 2)",
        url: "https://www.acenet.training/course/introduction-to-python-programming"},
       {title: "Using Spreadsheets for Organizing Data",
        url: "https://www.acenet.training/course/using-spreadsheets-for-organizing-data"},
       {title: "Big Data Analysis with Apache Spark (part 1 of 2)",
        url: "https://www.acenet.training/course/apache-spark"},
       {title: "Big Data Analysis with Apache Spark (part 2 of 2)",
        url: "https://www.acenet.training/course/apache-spark"}]

    new_events.each do |new_event|
      refute Event.where(title: new_event[:title], url: new_event[:url]).any?
    end

    # run task
    assert_difference 'Event.count', 6 do
      freeze_time(2025) do
        # Note: VCR does strange things with multiple same query parameters (e.g., access)
        VCR.use_cassette("ingestors/acenet_learn_worlds") do
          ingestor.token = source.token
          ingestor.read(source.url)
          #binding.pry
          ingestor.write(@user, @content_provider)
        end
      end
    end

    assert_equal 6, ingestor.events.count
    assert ingestor.materials.empty?
    assert_equal 6, ingestor.stats[:events][:added]
    assert_equal 0, ingestor.stats[:events][:updated]
    assert_equal 0, ingestor.stats[:events][:rejected]

    # Check events now do exist
    new_events.each do |new_event|
      event = Event.where(title: new_event[:title], url: new_event[:url]).first
      assert event

      # For now, all events should be online
      assert_equal event.online?, true
    end
    # TODO: More checks to come ...
  end
end
