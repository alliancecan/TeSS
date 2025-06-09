require 'open-uri'
require 'csv'

module Ingestors
  class EventbriteQuasiScraperIngestor < EventbriteIngestor
    # The Eventbrite API won't allow you to look at an organization's
    # events unless you (as a user) are a member of that organization
    # This ingestor uses web scraping to index the events, then uses
    # the API to get the event details.
    EVENT_ENDPOINT = "#{API_BASE}/events/%<id>s/?expand=venue"

    # Note: the token used is the private token (not secret key) from Eventbrite
    def self.config
      {
        key: 'eventbrite_quasi_scraper',
        title: 'Eventbrite scraper/REST API hybrid',
        category: :events
      }
    end

    private

    # Fetching and scraping event ids from the organization page
    def event_ids
      # Eventbrite is horrible. Rather than rendering events on the organization
      # page, they store the data for events in JSON and then render using JS.
      # With that in mind, what follow is likely quite brittle, as we try to
      # extract the JSON data to grab the event ids

      return @event_ids if @event_ids
      match = organization_response.body.match(/_SERVER_DATA__ = (\{.*\})/)
      return [] unless match

      json = JSON.parse(match[1])
      events = json.dig('view_data', 'events', 'future_events')
      events = json.dig('view_data', 'events', 'past_events') unless events.present?
      return [] unless events.present?

      @event_ids = events.map {|item| item['id']}
    end

    def organization_response
      @organization_response ||=
        RestClient::Request.execute(method: :get, url: url)
    end

    def fetch_event_items
      event_ids.map { |event_id| event_body(event_id) }
    end

    def event_body(id)
      get_json_response(format(EVENT_ENDPOINT, id: id))
    end

    def process_eventbrite
      @records_read = 0
      @records_inactive = 0
      @records_expired = 0

      begin
        items = fetch_event_items
        items.each do |item|
          event = process_event(item)

          # add event to events array
          add_event(event) if event
        end
      rescue Exception => e
        @messages << "#{self.class} failed with: #{e.message}"
      end

      @messages << "Eventbrite events ingestor: records read[#{@records_read}] "\
                   "inactive[#{@records_inactive}] expired[#{@records_expired}]"
    end

    def get_event_times_from_item(event, item)
      event.timezone = normalize_timezone(item['start']['timezone'])
      event.start = item['start']['utc']
      event.end = item['end']['utc']
    end

    def normalize_timezone(input)
      # Common Canadian time zones seen in the wild.
      # These don't appear in ActiveSupport::TimeZone::MAPPING
      # TODO: put this in Ingestor or in WithTimezone concern
      # TODO: refactor similar code in DracIcalIngestor
      case input
      when /Vancouver/
        return 'Pacific Time (US & Canada)'
      when /Edmonton/
        return 'Mountain Time (US & Canada)'
      when /Toronto/, /Montreal/
        return 'Eastern Time (US & Canada)'
      when /Moncton/
        return 'Atlantic Time (Canada)'
      end

      input
    end

  end
end
