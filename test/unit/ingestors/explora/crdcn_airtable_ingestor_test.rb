require 'test_helper'

class CrdcnAirtableIngestorTest < ActiveSupport::TestCase
  setup do
    @user = users(:regular_user)
    @content_provider = content_providers(:acenet)
    mock_ingestions
    mock_timezone # System time zone should not affect test result
  end

  teardown do
    reset_timezone
  end

  test 'can ingest events from the CRDCN Airtable' do
    source = @content_provider.sources.build(
      url: 'https://doesnt-matter.com',
      method: 'crdcn_airtable',
      token: '{"api_key": "redacted_api_key", "base_id": "redacted_base_id","table_id": "redacted_table_id"}',
      enabled: true
    )

    ingestor = Ingestors::Explora::CrdcnAirtableIngestor.new

    EST_OFFSET = "-500"
    EDT_OFFSET = "-400"

    # Check events doesn't already exist.
    # Ten events are in the data, we're just going to test two of them
    # (Standard time and daylight savings ... these always start at 1pm in Ontario).
    new_events =
      [{title: "CRDCN-StatCan Open Mic - Business Data",
        url: "https://crdcn.ca/events/crdcn-statcan-open-mic-business-data/",
        start: DateTime.new(2026, 2, 5, 13, 00, 0, EST_OFFSET),
        end: DateTime.new(2026, 2, 5, 14, 00, 0, EST_OFFSET)},

       {title: "CRDCN-StatCan Open Mic - Indigenous Data",
        url: "https://crdcn.ca/events/crdcn-statcan-open-mic-indigenous-data/",
        start: DateTime.new(2025, 9, 25, 13, 00, 0, EDT_OFFSET),
        end: DateTime.new(2025, 9, 25, 14, 15, 0, EDT_OFFSET)},
      ]

    new_events.each do |new_event|
      refute Event.where(title: new_event[:title], url: new_event[:url]).any?
    end

    # run task
    assert_difference 'Event.count', 10 do
      freeze_time(2025) do
        # Note: VCR does strange things with multiple same query parameters (e.g., access)
        VCR.use_cassette("ingestors/crdcn_airtable") do
          ingestor.token = source.token
          ingestor.read(source.url)

          ingestor.write(@user, @content_provider)
        end
      end
    end

    assert_equal 10, ingestor.events.count
    assert ingestor.materials.empty?
    assert_equal 10, ingestor.stats[:events][:added]
    assert_equal 0, ingestor.stats[:events][:updated]
    assert_equal 0, ingestor.stats[:events][:rejected]

    # Check events now do exist
    new_events.each do |new_event|
      event = Event.where(title: new_event[:title], url: new_event[:url]).first
      assert event

      # For now, all events should be online
      assert_equal event.online?, true
      # Multi-day events have the full dates in the description
      if new_event.key?(:description_include)
        refute_empty new_event[:description_include]
        assert_match new_event[:description_include], event.description
      end
      assert_equal event.start.to_i, new_event[:start].to_i
      assert_equal event.end.to_i, new_event[:end].to_i
    end
    # TODO: More checks to come ...
  end
end
