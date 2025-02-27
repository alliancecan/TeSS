require 'date'

module Ingestors
  class AcenetLearnWorldsIngestor < Ingestor
    # The ics files from Google tend to embed the timezone in
    # the calendar, not the events
    attr_reader :default_timezone

    ACENET_COURSES_BASE_URL = 'https://www.acenet.training/course'
    ACCESS_QUERY = 'access=paid&access=free'

    def self.config
      {
        key: 'acenet_learn_worlds',
        title: 'ACENET LearnWorlds',
        category: :events
      }
    end

    def read(url)
      process_learn_worlds(url)
    rescue Exception => e
      @messages << "#{self.class.name} failed with: #{e.message}"
    ensure
      nil
    end

    private

    def parsed_token
      @parsed_token ||= JSON.parse(@token)
    end

    def access_token
      @aceess_token ||= parsed_token['access_token']
    end

    def client_id
      @client_id ||= parsed_token['client_id']
    end

    def get_page_url(url, page = 1)
      full_url = "#{url}/admin/api/v2/courses?#{ACCESS_QUERY}"
      full_url = if page && page > 1
                   "#{full_url}&page=#{page}"
                 else
                   full_url
                 end
    end

    def get_json_response(url, page = 1)
      full_url = get_page_url(url, page)
      response = RestClient::Request.new(method: :get,
                                         url: CGI.unescape_html(full_url),
                                         headers: { accept: 'application/json',
                                                    authorization: "Bearer #{access_token}",
                                                    'Lw-Client' => client_id}).execute
      # check response
      raise "invalid response code: #{response.code}" unless response.code == 200

      JSON.parse(response.to_str)
    end

    def process_learn_worlds(url)
      pages = nil
      page = 1
      while(true)
        json = get_json_response(url, page)
        pages ||= json.dig('meta', 'totalPages')
        process_data(json['data'])
        if pages
          break if page == pages
        end
        page += 1
      end
    end

    def process_data(data)
      data.each do |item|
        internal_events = item_to_events(item)
        internal_events.each do |event|
          add_event(event)
        end
      end
    end

    def item_to_events(item)
      internal_events = []

      # Dates and times are encoded as text in the label
      datetimes = item['label']
      start_ends = datetimes_to_start_ends(datetimes)
      if start_ends.blank?
        Rails.logger.error("Datetimes (label) not parsable for #{item['id']}: #{datetimes}")
        return []
      end

      # For now we have to inject multiple events for multiday events
      start_ends.each_with_index do |start_end, i|
        event = OpenStruct.new
        event.slug = item['id']
        event.external_id = "#{item['id']}-#{item['created']}"
        event.title = item['title']
        if start_ends.count > 1
          event.external_id += "-part-#{i+1}-of-#{start_ends.count}"
          event.slug += "-part-#{i+1}-of-#{start_ends.count}"
          event.title += " (part #{i+1} of #{start_ends.count})"
        end

        event.url = "#{ACENET_COURSES_BASE_URL}/#{item['id']}"

        event.start = start_end.start
        event.end = start_end.end

        event.description = item['description']

        internal_events << event
      end

      return internal_events
    end

    def datetimes_to_start_ends(datetimes)
      start_ends = []

      dates_and_times = datetimes&.split('|')&.map(&:strip)
      return [] if dates_and_times.blank?

      dates = get_dates(dates_and_times[0])
      return [] unless dates.present?

      match = /(.*)\-(.*).*\((.*)\)/.match(dates_and_times[1])
      return [] unless match

      start_with_meridian = get_time_with_meridian(match[1])
      end_with_meridian = get_time_with_meridian(match[2])
      # Assume that at least the end time has a meridian
      start_with_meridian[1] ||= end_with_meridian[1]

      timezone = get_timezone(match[3].strip)
      
      dates.each do |date|
        start_end = OpenStruct.new
        start_end.start = get_datetime(date, start_with_meridian[0], start_with_meridian[1], timezone)
        start_end.end = get_datetime(date, end_with_meridian[0], end_with_meridian[1], timezone)

        start_ends << start_end
      end
      return start_ends
    end

    def get_dates(dates_str)
      dates = []
      days = []

      match = /([a-zA-Z]+)(.*),\s*([0-9]{4})/.match(dates_str)
      month = match[1]
      year = match[3]
      dash_day = match[2].split('-')&.map(&:to_i)
      if dash_day.count == 2
        days = (dash_day[0]..dash_day[1])
      else
        days = match[2].split(',')&.map(&:to_i)
        return [] unless days.present?
      end
      days.each do |day|
        dates << Date.parse("#{month} #{day}, #{year}")
      end
      return dates
    end

    def get_datetime(date, time, meridian, timezone)
      datetime_str = "#{date} #{time} #{meridian}"
      timezone.parse(datetime_str)
    end

    def get_time_with_meridian(str)
      match = /(^\S*)\s*([ap]m)?/i.match(str&.strip)
      return nil unless match

      return [match[1].strip, match[2]&.strip&.downcase]
    end

    def get_timezone(timezone_str)
      if timezone_str == 'Atlantic'
        return ActiveSupport::TimeZone["America/Halifax"]
      elsif timezone_str == 'Newfoundland'
        return ActiveSupport::TimeZone["America/St_Johns"]
      end
      raise StandardError.new("Timezone not recognized (#{timezone_str})")
    end

  end
end
