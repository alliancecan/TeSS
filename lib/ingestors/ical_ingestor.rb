require 'icalendar'
require 'nokogiri'
require 'open-uri'
require 'tzinfo'

module Ingestors
  class IcalIngestor < Ingestor
    attr_reader :icalendars

    # The ics files from Google tend to embed the timezone in
    # the calendar, not the events
    attr_reader :default_timezone

    def self.config
      {
        key: 'ical',
        title: 'iCalendar',
        category: :events
      }
    end

    def read(url)
      unless url.nil?
        if url.to_s.downcase.end_with? 'sitemap.xml'
          process_sitemap url
        else
          process_icalendar url
        end
      end
    end

    private

    def process_sitemap(url)
      # find urls for individual icalendar files
      begin
        sitemap = Nokogiri::XML.parse(open_url(url, raise: true))
        locs = sitemap.xpath('/ns:urlset/ns:url/ns:loc', {
                               'ns' => 'http://www.sitemaps.org/schemas/sitemap/0.9'
                             })
        locs.each do |loc|
          process_icalendar(loc.text)
        end
      rescue Exception => e
        @messages << "Extract from sitemap[#{url}] failed with: #{e.message}"
      end

      # finished
      nil
    end

    def full_url(url)
      # append query  (if required)
      query = '?ical=true'
      return url + query unless url.to_s.downcase.ends_with? query
      url
    end

    def process_icalendar(url)
      # process individual ics file
      file_url = full_url(url)

      begin
        # process file
        vcalendars =
          Icalendar::Calendar
            .parse(open_url(file_url, raise: true)
                     .set_encoding('utf-8'))
        vcalendars.each do |vcal|
          @default_timezone = vcal&.custom_properties&.fetch('x_wr_timezone')&.first
          vcal.events.each do |e|
            process_event(e)
          end
        end
      rescue Exception => e
        @messages << "Process file url[#{file_url}] failed with: #{e.message}"
      end

      # finished
      nil
    end

    def ical_event_online?(calevent)
      calevent.location.downcase.include?('online')
    end

    # Return the start or end date of the iCalendar event as a Time
    # object.
    def extract_event_date(calevent, what)
      calevent.send(("dt" + what.to_s).to_sym)&.to_time
    end

    def extract_event_timezone(calevent)
      tzid = calevent.dtstart.ical_params['tzid']
      # Sometimes it's an array ...
      tzid = tzid.first if tzid.is_a? Array
      tzid = tzid.to_s unless tzid.nil?

      return default_timezone if (!default_timezone.nil? && (tzid.nil? || tzid == 'UTC'))
      tzid
    end

    def extract_url(calevent)
      calevent.url.to_s
    end

    def process_event(calevent)
      # puts "calevent: #{calevent.inspect}"
      begin
        # set fields
        event = OpenStruct.new
        event.url = extract_url(calevent)
        event.title = calevent.summary.to_s
        event.external_id = calevent&.uid&.to_s

        event.timezone = extract_event_timezone(calevent)

        event.start = extract_event_date(calevent, :start)
        event.end = extract_event_date(calevent, :end)

        event.venue = calevent.location.to_s
        if ical_event_online?(calevent)
          event.online = true
          event.city = nil
          event.postcode = nil
          event.country = nil
          # CW: wipe the venue when online too
          event.venue = nil
        else
          location = convert_location(calevent.location)
          event.city = location['suburb'] unless location['suburb'].nil?
          event.country = location['country'] unless location['country'].nil?
          event.postcode = location['postcode'] unless location['postcode'].nil?
        end
        event.keywords = []
        unless calevent.categories.nil? or calevent.categories.first.nil?
          cats = calevent.categories.first
          if cats.is_a?(Icalendar::Values::Array)
            cats.each do |item|
              event.keywords << item.to_s.lstrip
            end
          else
            event.keywords << cats.to_s.strip
          end
        end

        # Update description, and potentially other fields too
        process_description_title(calevent.description, event.title, event)

        # store event
        @events << event
      rescue Exception => e
        @messages << "Process iCalendar failed with: #{e.message}"
      end

      # finished
      nil
    end

    def process_description_title(description, title, event)
      return if description.nil?

      event.description = convert_description(description.to_s.gsub(/\R/, '<br />'))
    end
  end
end
