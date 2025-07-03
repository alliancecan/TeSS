require 'test_helper'

class LibcalAbIngestorTest < ActiveSupport::TestCase
  # Npte: we just use the BC data, but pretend it's from an Alberta provider
  # Local times will be the same, UTC times will be one hour different
  setup do
    @user = users(:regular_user)
    @content_provider = content_providers(:another_portal_provider)
    mock_ingestions
    # mock_nominatim
    mock_timezone # System time zone should not affect test result
  end

  teardown do
    reset_timezone
  end

  # Sitemap tests removed

  test 'Ingest libcal AB source' do
    # override time
    assert_difference('Event.count', 3) do
      freeze_time(2019) do
        ingestor = Ingestors::LibcalAbIngestor.new
        source = @content_provider.sources.build(
          url: 'https://www.libcal-bc.ca/ajax/calendar/list?c=7544&date=0000-00-00&cats=33865',
          method: 'libcal_event_ab', enabled: true
        )
        ingestor.read(source.url)
        ingestor.write(@user, @content_provider)

        assert_equal 3, ingestor.events.count
        assert ingestor.materials.empty?

        assert_equal 3, ingestor.stats[:events][:added]
        assert_equal 0, ingestor.stats[:events][:updated]
        assert_equal 0, ingestor.stats[:events][:rejected]

        ### Event 1
        event = ingestor.events.detect { |e| e.title == 'Data Bites - Creating README Files for Research Data' }
        assert event
        assert_equal(event.url, 'https://libcal.library.ubc.ca/event/3899771')
        assert_equal(event.keywords.sort, ['Data', 'Digital Scholarship',
                                           'Research Commons', 'Research Data Management'])
        assert_equal(event.presence, 'online')
        assert_equal(event.timezone, 'Mountain Time (US & Canada)')
        assert_equal(event.start_local.to_s, '2025-06-02 12:30:00 -0600')
        assert_equal(event.end_local.to_s, '2025-06-02 13:00:00 -0600')

        ### Event 2
        event = ingestor.events.detect { |e| e.title == 'Data Bites - Creating README Files with Markdown' }
        assert event
        assert_equal(event.url, 'https://libcal.library.ubc.ca/event/3900593')
        assert_nil(event.language)
        assert_equal(event.keywords.sort, ['Data', 'Digital Scholarship',
                                           'Research Commons', 'Research Data Management'])
        assert_equal(event.presence, 'online')
        assert_equal(event.timezone, 'Mountain Time (US & Canada)')
        assert_equal(event.start_local.to_s, '2025-06-03 12:30:00 -0600')
        assert_equal(event.end_local.to_s, '2025-06-03 13:00:00 -0600')

        ### Event 3
        event = ingestor.events.detect { |e| e.title =~ /Introduction to Git and GitHub: Part 2/ }
        assert event
        assert_equal(event.url, 'https://libcal.library.ubc.ca/event/3903068')
        assert_nil(event.language)
        # Note to self: event has to have a location set or 'onsite' will not stick.
        assert_equal(event.presence, 'online')
        assert_equal(event.keywords.sort, ['Digital Scholarship', 'Research Commons',
                                           'Research Data Management'])
        assert_equal(event.timezone, 'Mountain Time (US & Canada)')
        assert_equal(event.start_local.to_s, '2025-06-04 11:00:00 -0600')
        assert_equal(event.end_local.to_s, '2025-06-04 13:00:00 -0600')
      end
    end
  end

end
