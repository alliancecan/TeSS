require 'test_helper'

class AcenetWordpressIngestorTest < ActiveSupport::TestCase
  setup do
    @user = users(:regular_user)
    @content_provider = content_providers(:acenet)
    mock_ingestions
    mock_timezone # System time zone should not affect test result
  end

  teardown do
    reset_timezone
  end

  test 'can ingest events from Acenet LearnWordpress' do
    source = @content_provider.sources.build(
      url: 'https://www.ace-net.ca/wp-json/acenet/v1/courses',
      method: 'acenet_wordpress',
      enabled: true
    )

    ingestor = Ingestors::Explora::AcenetWordpressIngestor.new

    # March 9, this changes to daylight savings ...
    ADT_OFFSET = "-300"
    NDT_OFFSET = "-230"

    # Check events doesn't already exist
    new_events =
      [{title: "Introduction to Computational Thinking – Dalhousie University",
        url: "https://www.ace-net.ca/training-course/introduction-to-computational-thinking/",
        online: false,
        start: DateTime.new(2026, 10, 9, 9, 0, 0, ADT_OFFSET),
        end: DateTime.new(2026, 10, 9, 12, 0, 0, ADT_OFFSET),
        venue_include: "St John's, Newfoundland"},

       {title: "Introduction to Computational Thinking – Memorial University",
        url: "https://www.ace-net.ca/training-course/introduction-to-computational-thinking-mun/",
        online: false,
        start: DateTime.new(2026, 10, 7, 13, 0, 0, NDT_OFFSET),
        end: DateTime.new(2026, 10, 7, 16, 0, 0, NDT_OFFSET),
        venue_include: 'Halifax, NS'},

       {title: "Microcredential in Practical Foundations for Data Analytics (7 parts)",
        url: "https://www.ace-net.ca/training-course/microcredential-in-practical-foundations-for-data-analytics/",
        online: true,
        start: DateTime.new(2026, 10, 20, 14, 00, 0, ADT_OFFSET),
        end: DateTime.new(2026, 10, 20, 17, 00, 0, ADT_OFFSET),
        description_include: /2026-10-20.*14:00.*17:00.*
                              2026-10-22.*14:00.*17:00.*
                              2026-10-27.*14:00.*17:00.*
                              2026-10-29.*14:00.*17:00.*
                              2026-11-03.*14:00.*17:00.*
                              2026-11-05.*14:00.*17:00.*
                              2026-11-10.*14:00.*17:00.*
                              America\/Halifax/mx},

       {title: "Introductory Programming: Unix Shell, Git and Python (4 parts)",
        url: "https://www.ace-net.ca/training-course/introductory-programming-unix-shell-git-and-python/",
        online: true,
        start: DateTime.new(2026, 9, 29, 13, 00, 0, ADT_OFFSET),
        end: DateTime.new(2026, 9, 29, 16, 00, 0, ADT_OFFSET),
        description_include: /2026-09-29.*13:00.*16:00.*
                              2026-10-01.*13:00.*16:00.*
                              2026-10-06.*13:00.*16:00.*
                              2026-10-08.*13:00.*16:00.*
                              America\/Halifax/mx}]

    new_events.each do |new_event|
      refute Event.where(title: new_event[:title], url: new_event[:url]).any?
    end

    # run task
    assert_difference 'Event.count', 4 do
      freeze_time(2025) do
        # Note: VCR does strange things with multiple same query parameters (e.g., access)
        VCR.use_cassette("ingestors/acenet_wordpress") do
          ingestor.token = source.token
          ingestor.read(source.url)

          ingestor.write(@user, @content_provider)
        end
      end
    end

    assert_equal 4, ingestor.events.count
    assert ingestor.materials.empty?
    assert_equal 4, ingestor.stats[:events][:added]
    assert_equal 0, ingestor.stats[:events][:updated]
    assert_equal 0, ingestor.stats[:events][:rejected]

    # Check events now do exist
    new_events.each do |new_event|
      event = Event.where(title: new_event[:title], url: new_event[:url]).first
      assert event

      assert_equal event.online?, new_event[:online]
      # Multi-day events have the full dates in the description
      if new_event.key?(:description_include)
        assert_match new_event[:description_include], event.description
      end
      assert_equal event.start, new_event[:start]
      assert_equal event.end, new_event[:end]
    end
    # TODO: More checks to come ...
  end
end
