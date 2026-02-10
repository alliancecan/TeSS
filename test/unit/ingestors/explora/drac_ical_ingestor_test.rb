require 'test_helper'

class DracIcalIngestorTest < ActiveSupport::TestCase
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

  test 'Ingest drac_ical source' do
    # override time
    assert_difference('Event.count', 3) do
      freeze_time(2019) do
        ingestor = Ingestors::Explora::DracIcalIngestor.new
        source = @content_provider.sources.build(
          url: 'https://www.drac-ical.ca/stuff/drac-ical1.ics',
          method: 'drac_ical', enabled: true
        )
        ingestor.read(source.url)
        ingestor.write(@user, @content_provider)

        assert_equal 3, ingestor.events.count
        assert ingestor.materials.empty?

        assert_equal 3, ingestor.stats[:events][:added]
        assert_equal 0, ingestor.stats[:events][:updated]
        assert_equal 0, ingestor.stats[:events][:rejected]

        event = ingestor.events.detect { |e| e.title == 'Test 1' }
        assert event
        assert_equal(event.url, 'https://www.some-fake-course.ca')
        assert_equal(event.language, 'fr')
        assert_equal(event.keywords.sort, ['Cats', 'Dogs'])

        # TODO: Default is 'online' ... change it?
        assert_equal(event.presence, 'online')

        event = ingestor.events.detect { |e| e.title == 'Test 2' }
        assert event
        assert_equal(event.url, 'https://www.some-other-fake-course.ca')
        assert_nil(event.language)
        assert_equal(event.presence, 'hybrid')
        assert_equal(event.keywords.sort, ["AI", "Machine Learning", 'Physics', 'Programming', 'Python'])

        event = ingestor.events.detect { |e| e.title =~ /Test 3/ }
        assert event
        assert_equal(event.url, 'https://what-a-great-course.com')
        assert_nil(event.language)
        # Note to self: event has to have a location set or 'onsite' will not stick.
        assert_equal(event.presence, 'onsite')
        assert_equal(event.venue, 'Aquarium of Quebec, 1675 Av. des Hôtels, Québec, QC G1W 4S3, Canada')
        assert_equal(event.keywords.sort, ['Editor', 'GPU', 'Git', 'HPC', 'Programming', 'Visualization'])
      end
    end
  end

end
