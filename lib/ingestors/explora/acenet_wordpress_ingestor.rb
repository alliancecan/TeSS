require 'date'

module Ingestors
  module Explora
    class AcenetWordpressIngestor < Ingestor
      def self.config
        {
          key: 'acenet_wordpress',
          title: 'ACENET Wordpress',
          category: :events
        }
      end

      def read(url)
        process_wordpress(url)
      rescue Exception => e
        @messages << "#{self.class.name} failed with: #{e.message}"
      ensure
        nil
      end

      private

      def get_json_response(url)
        response = RestClient::Request.new(method: :get,
                                           url: CGI.unescape_html(url),
                                           headers: { accept: 'application/json' }).execute
        # check response
        raise "invalid response code: #{response.code}" unless response.code == 200

        JSON.parse(response.to_str)
      end

      def process_wordpress(url)
        # Assumption: no pagination
        json = get_json_response(url)
        process_data(json)
      end

      def process_data(data)
        data.each do |item|
          event = item_to_event(item)
          add_event(event) if event.present?
        end
      end

      def item_dates_starts_ends(item)
        # This is less than optimal.
        # There can be multiple sessions, and sessions can have multiple dates.
        # We gather into an array of start/ends strings
        item['sessions'].map do |s|
          s['dates'].map {|d| [d, s['start'], s['end']]}
        end.flatten(1)
      end

      def item_to_event(item)
        # Inject single event, be mindful of multiday events
        event = OpenStruct.new
        event.url = item['url']
        event.slug = "#{item['slug']}-#{item['id']}"
        event.external_id = "acenet-wordpress-#{event.slug}"
        event.title = item['title']

        event.description = item['description']['rendered']

        event.timezone = item['timezone']
        dates_starts_ends = item_dates_starts_ends(item)
        session_count = dates_starts_ends.count
        if session_count > 1
          event.title += " (#{session_count} parts)"
          datetimes = dates_starts_ends.map {|dse| "#{dse[0]}@#{dse[1]} - #{dse[2]}" }
          event.description = "#{datetimes.join('<br>')}\n#{event.timezone}\n\n#{event.description}"
        end

        date = dates_starts_ends.first[0]
        start_time = dates_starts_ends.first[1]
        end_time = dates_starts_ends.first[2]
        event.start = get_datetime(date, start_time, event.timezone)
        event.end = get_datetime(date, end_time, event.timezone)

        event.online = (item['location'].strip.downcase == 'online')
        unless event.online
          event.venue = item['location']
        end

        return event
      end

      def get_datetime(date, time, timezone_str)
        timezone = get_timezone(timezone_str)
        datetime_str = "#{date} #{time}"
        timezone.parse(datetime_str)
      end

      def get_timezone(timezone_str)
        if timezone_str == "America/Halifax"
          return ActiveSupport::TimeZone["America/Halifax"]
        elsif timezone_str == "America/St_Johns"
          return ActiveSupport::TimeZone["America/St_Johns"]
        end
        raise StandardError.new("Timezone not recognized (#{timezone_str})")
      end

    end
  end
end
