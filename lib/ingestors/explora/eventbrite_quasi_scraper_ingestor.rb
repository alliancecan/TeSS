require 'open-uri'
require 'csv'
require 'nokogiri'

module Ingestors
  module Explora
    class EventbriteQuasiScraperIngestor < EventbriteIngestor
      # The Eventbrite API won't allow you to look at an organization's
      # events unless you (as a user) are a member of that organization
      # This ingestor uses web scraping to index the events, then uses
      # the API to get the event details.

      include Ingestors::Concerns::NormalizeTimezone

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
        # Eventbrite is horrible. They change the schema of their pages whenever they want.
        # Rather than rendering events on the organization
        # page, they store the data for events in JSON and then render using JS.
        # With that in mind, what follow is likely quite brittle, as we try to
        # extract the JSON data to grab the event ids.
        # Previously, this information was extractable from anchor tags.
        return @event_ids if @event_ids

        tree = Nokogiri::HTML5.parse(organization_response.body)
        @event_ids = JSON.parse(tree.css('script#__NEXT_DATA__').text)&.\
                       dig('props', 'pageProps', 'upcomingEvents')&.\
                       map{|e| e['eventbrite_event_id']} || []
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

    end
  end
end
