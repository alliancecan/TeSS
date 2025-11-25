require 'test_helper'

class IngestorTest < ActiveSupport::TestCase
  test 'convert HTML descriptions to markdown where appropriate' do
    ingestor = Ingestors::Ingestor.new

    input = "### Title\n\nAmpersands & Quotes \""
    expected = input
    assert_equal expected, ingestor.convert_description(input)

    input = "<h1>Title</h1><ul><li>Item 1</li><li>Item 2</li>"
    expected = "# Title\n\n- Item 1\n- Item 2"
    assert_equal expected, ingestor.convert_description(input)
  end

  test 'sets event language from source default language' do
    user = users(:scraper_user)
    provider = content_providers(:portal_provider)

    # Source has default language set
    @source = Source.create!(url: 'https://somewhere.com/stuff', method: 'bioschemas',
                             enabled: true, approval_status: 'approved',
                             default_language: 'fr',
                             content_provider: provider, user: users(:admin))

    ingestor = Ingestors::Ingestor.new

    # Fake an event that was read ... no language set
    ingestor.instance_variable_set(:@events,
                                   [OpenStruct.new(url: 'https://some-course.ca',
                                                   title: 'Some course',
                                                   start: '2021-01-31 13:00:00',
                                                   end:'2021-01-31 14:00:00')])
    assert_difference('provider.events.count', 1) do
      ingestor.write(user, provider, source: @source)
    end
    event = Event.find_by(title: 'Some course')
    assert_equal(event.language, 'fr')
  end

  test 'does not override event language from source default language when language set' do
    user = users(:scraper_user)
    provider = content_providers(:portal_provider)

    # Source has default language set
    @source = Source.create!(url: 'https://somewhere.com/stuff', method: 'bioschemas',
                             enabled: true, approval_status: 'approved',
                             default_language: 'fr',
                             content_provider: provider, user: users(:admin))

    ingestor = Ingestors::Ingestor.new

    # Fake an event that was read ... with language set
    ingestor.instance_variable_set(:@events,
                                   [OpenStruct.new(url: 'https://some-course.de',
                                                   title: 'Some german course',
                                                   start: '2021-01-31 13:00:00',
                                                   end:'2021-01-31 14:00:00',
                                                   language: 'de')])
    assert_difference('provider.events.count', 1) do
      ingestor.write(user, provider, source: @source)
    end
    event = Event.find_by(title: 'Some german course')
    assert_equal(event.language, 'de')
  end

  test 'does not override event language when source default language missing' do
    user = users(:scraper_user)
    provider = content_providers(:portal_provider)

    # Source has no default language set
    @source = Source.create!(url: 'https://somewhere.com/stuff', method: 'bioschemas',
                             enabled: true, approval_status: 'approved',
                             content_provider: provider, user: users(:admin))

    ingestor = Ingestors::Ingestor.new

    # Fake an event that was read ... with language set
    ingestor.instance_variable_set(:@events,
                                   [OpenStruct.new(url: 'https://some-course.org',
                                                   title: 'Some other course',
                                                   start: '2021-01-31 13:00:00',
                                                   end:'2021-01-31 14:00:00',
                                                   language: 'de')])
    assert_difference('provider.events.count', 1) do
      ingestor.write(user, provider, source: @source)
    end
    event = Event.find_by(title: 'Some other course')
    assert_equal(event.language, 'de')
  end

  test 'does not set event language when languare and source default language missing' do
    user = users(:scraper_user)
    provider = content_providers(:portal_provider)

    # Source has no default language set
    @source = Source.create!(url: 'https://somewhere.com/stuff', method: 'bioschemas',
                             enabled: true, approval_status: 'approved',
                             content_provider: provider, user: users(:admin))

    ingestor = Ingestors::Ingestor.new

    # Fake an event that was read ... no language set
    ingestor.instance_variable_set(:@events,
                                   [OpenStruct.new(url: 'https://some-course.net',
                                                   title: 'Yet another course',
                                                   start: '2021-01-31 13:00:00',
                                                   end:'2021-01-31 14:00:00')])
    assert_difference('provider.events.count', 1) do
      ingestor.write(user, provider, source: @source)
    end
    event = Event.find_by(title: 'Yet another course')
    assert_nil(event.language)
  end

  test 'excludes an event when the title matches a pattern' do
    user = users(:scraper_user)
    provider = content_providers(:portal_provider)

    # Source has default language set
    @source = Source.create!(url: 'https://somewhere.com/exclude1', method: 'bioschemas',
                             enabled: true, approval_status: 'approved',
                             exclude_patterns: {title: ["Hamburger", "Hot Dog", '/Milk shake/i']},
                             content_provider: provider, user: users(:admin))

    ingestor = Ingestors::Ingestor.new

    # Fake an event that was read ... no language set
    ingestor.instance_variable_set(:@events,
                                   [OpenStruct.new(url: 'https://some-course-hamburger.ca',
                                                   title: 'Some Hamburger course',
                                                   start: '2021-01-31 13:00:00',
                                                   end:'2021-01-31 14:00:00'),
                                    OpenStruct.new(url: 'https://some-course-hamburgerz.ca',
                                                   title: 'Some hamburger course',
                                                   start: '2021-01-31 13:00:00',
                                                   end:'2021-01-31 14:00:00'),
                                    OpenStruct.new(url: 'https://some-course-hot-dog.ca',
                                                   title: 'Some Hot Dog course',
                                                   start: '2021-01-31 13:00:00',
                                                   end:'2021-01-31 14:00:00'),
                                    OpenStruct.new(url: 'https://some-course-milk-shake.ca',
                                                   title: 'Some Milk Shake course',
                                                   start: '2021-01-31 13:00:00',
                                                   end:'2021-01-31 14:00:00'),
                                    OpenStruct.new(url: 'https://some-course-milk-shakez.ca',
                                                   title: 'Some milk shake course',
                                                   start: '2021-01-31 13:00:00',
                                                   end:'2021-01-31 14:00:00'),
                                    OpenStruct.new(url: 'https://some-course-veggie.ca',
                                                   title: 'Some veggie course',
                                                   start: '2021-01-31 13:00:00',
                                                   end:'2021-01-31 14:00:00')])

    assert_difference('provider.events.count', 2) do
      ingestor.write(user, provider, source: @source)
    end

    event = Event.find_by(title: 'Some Hamburger course')
    assert_nil event
    event = Event.find_by(title: 'Some hamburger course')
    refute_nil event
    event = Event.find_by(title: 'Some Hot Dog course')
    assert_nil event
    event = Event.find_by(title: 'Some Milk Shake course')
    assert_nil event
    event = Event.find_by(title: 'Some milk shake course')
    assert_nil event
    event = Event.find_by(title: 'Some veggie course')
    refute_nil event
  end

  test 'excludes an event when the description matches a pattern' do
    # Short test, much of the behaviour is identical to the above
    user = users(:scraper_user)
    provider = content_providers(:portal_provider)

    # Source has default language set
    @source = Source.create!(url: 'https://somewhere.com/exclude1', method: 'bioschemas',
                             enabled: true, approval_status: 'approved',
                             exclude_patterns: {description: ["Cat"]},
                             content_provider: provider, user: users(:admin))

    ingestor = Ingestors::Ingestor.new

    # Fake an event that was read ... no language set
    ingestor.instance_variable_set(:@events,
                                   [OpenStruct.new(url: 'https://some-course-cat.ca',
                                                   title: 'Some course 1',
                                                   description: 'Some Cat course',
                                                   start: '2021-01-31 13:00:00',
                                                   end:'2021-01-31 14:00:00'),
                                    OpenStruct.new(url: 'https://some-course-catz.ca',
                                                   title: 'Some course 2',
                                                   description: 'Some cat course',
                                                   start: '2021-01-31 13:00:00',
                                                   end:'2021-01-31 14:00:00')])
    assert_difference('provider.events.count', 1) do
      ingestor.write(user, provider, source: @source)
    end

    event = Event.find_by(title: 'Some course 1')
    assert_nil event
    event = Event.find_by(title: 'Some course 2')
    refute_nil event
  end

  test 'excludes an event when the title or description matches a pattern' do
    # Short test, much of the behaviour is identical to the above
    user = users(:scraper_user)
    provider = content_providers(:portal_provider)

    # Source has default language set
    @source = Source.create!(url: 'https://somewhere.com/exclude1', method: 'bioschemas',
                             enabled: true, approval_status: 'approved',
                             exclude_patterns: {title: ['/Dog\s+course/'],
                                               description: ["/some.*thing/i"]},
                             content_provider: provider, user: users(:admin))

    ingestor = Ingestors::Ingestor.new

    # Fake an event that was read ... no language set
    ingestor.instance_variable_set(:@events,
                                   [OpenStruct.new(url: 'https://some-course-cat.ca',
                                                   title: 'Some Dog  course Z',
                                                   description: 'Some Cat course',
                                                   start: '2021-01-31 13:00:00',
                                                   end:'2021-01-31 14:00:00'),
                                    OpenStruct.new(url: 'https://some-course-catz.ca',
                                                   title: 'Some course ZZ',
                                                   description: 'Some words about this cat course thing',
                                                   start: '2021-01-31 13:00:00',
                                                   end:'2021-01-31 14:00:00'),
                                    OpenStruct.new(url: 'https://some-course-catz.ca',
                                                   title: 'Some course ZZZ',
                                                   description: 'Nothing about this cat course',
                                                   start: '2021-01-31 13:00:00',
                                                   end:'2021-01-31 14:00:00')])
    assert_difference('provider.events.count', 1) do
      ingestor.write(user, provider, source: @source)
    end

    event = Event.find_by(title: 'Some Dog course Z')
    assert_nil event
    event = Event.find_by(title: 'Some course ZZ')
    assert_nil event
    event = Event.find_by(title: 'Some course ZZZ')
    refute_nil event
  end


end
