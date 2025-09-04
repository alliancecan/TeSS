require 'open-uri'
require 'csv'

module Ingestors
  class EventbriteIngestor < Ingestor
    API_BASE = 'https://www.eventbriteapi.com/v3'
    ORGANIZER_ENDPOINT = "#{API_BASE}/organizers/%<id>s/"
    FORMATS_ENDPOINT = "#{API_BASE}/formats/"
    VENUE_ENDPOINT = "#{API_BASE}/venues/%<id>s/"
    CATEGORIES_ENDPOINT = "#{API_BASE}/categories/"
    CATEGORIES_PAGE_ENDPOINT = "#{API_BASE}/categories/?page=%<page>d"

    EVENTS_ENDPOINT = '%<url>s/events/?status=live'
    EVENTS_PAGE_ENDPOINT = '%<url>s/events/?page=%<page>d'

    attr_reader :url

    def self.config
      {
        key: 'eventbrite',
        title: 'Eventbrite REST API',
        category: :events
      }
    end

    def initialize
      super
      @eventbrite_objects = {}
    end

    def read(url)
      @url = url
      begin
        # process url
        process_eventbrite
      rescue Exception => e
        @messages << "#{self.class.name} failed with: #{e.message}"
      end

      # finished
      nil
    end

    private

    def process_eventbrite
      @records_read = 0
      @records_inactive = 0
      @records_expired = 0

      begin
        # initialise next_page
        next_page = format(EVENTS_ENDPOINT, url: url)

        while next_page
          # execute REST request
          results = get_json_response next_page

          # check next page
          next_page = nil
          pagination = results['pagination']
          begin
            if !(pagination.nil? or pagination['has_more_items'].nil? or pagination['page_number'].nil?) && (pagination['has_more_items'])
              page = pagination['page_number'].to_i
              next_page = format(EVENTS_PAGE_ENDPOINT, url: url, page: page + 1)
            end
          rescue Exception => e
            puts "format next_page failed with: #{e.message}"
          end

          # check events
          events = results['events']
          next if events.nil? or events.empty?

          events.each do |item|
            event = process_event(item)

            # add event to events array
            add_event(event) if event
          end
        end
      rescue Exception => e
        @messages << "#{self.class} failed with: #{e.message}"
      end

      # finished
      @messages << "Eventbrite events ingestor: records read[#{@records_read}] "\
                   "inactive[#{@records_inactive}] expired[#{@records_expired}]"
      nil
    end

    def process_event(item)
      @records_read += 1

      if item['status'].nil? or item['status'] != 'live'
        @records_inactive += 1
        return
      end

      event = OpenStruct.new

      # check for expired
      get_event_times_from_item(event, item)
      if event.expired?
        @records_expired += 1
        return
      end

      # set required attributes
      event.title = item['name']['text'] unless item['name'].nil?
      event.url = item['url']
      event.description = convert_description item['description']['html'] unless item['description'].nil?
      event.online = if item['online_event'].nil? or item['online_event'] == false
                       false
                     else
                       true
                     end

      # This is a bit of a kludge: Eventbrite handles in-person and online events, not hybrid
      event.presence = :hybrid if event.description =~ /\b[Hh]ybrid\b/

      # organizer
      organizer = get_eventbrite_organizer item['organizer_id']
      event.organizer = organizer['name'] unless organizer.nil?

      event.external_id = item['id']

      # address fields
      venue = get_eventbrite_venue item['venue_id']
      unless venue.nil? or venue['address'].nil?
        address = venue['address']
        venue = address['address_1']
        venue += (', ' + address['address_2']) unless address['address_2'].blank?
        event.venue = venue
        event.city = address['city']
        event.country = address['country']
        event.postcode = address['postal_code']
        event.latitude = address['latitude']
        event.longitude = address['longitude']
      end

      # set optional attributes
      event.keywords = []
      category = get_eventbrite_category item['category_id']
      subcategory = get_eventbrite_subcategory(item['subcategory_id'], item['category_id'])
      event.keywords << category['name'] unless category.nil?
      event.keywords << subcategory['name'] unless subcategory.nil?

      event.capacity = item['capacity'].to_i unless item['capacity'].nil? or item['capacity'] == 'null'

      event.event_types = []
      format = get_eventbrite_format item['format_id']
      unless format.nil?
        type = convert_event_types format['short_name']
        event.event_types << type unless type.nil?
      end

      event.eligibility = if item['invite_only'].nil? or !item['invite_only']
                            'open_to_all'
                          else
                            'by_invitation'
                          end

      if item['is_free'].nil? or !item['is_free']
        event.cost_basis = 'charge'
        event.cost_currency = item['currency']
      else
        event.cost_basis = 'free'
      end

      return event
    rescue Exception => e
      @messages << "Extract event fields failed with: #{e.message}"
    end

    def get_event_times_from_item(event, item)
      event.timezone = item['start']['timezone']
      event.start = item['start']['local']
      event.end = item['end']['local']
    end

    def normalize_timezone(input)
      return input
    end

    def get_eventbrite_format(id)
      # initialise cache
      @eventbrite_objects[:formats] = {} if @eventbrite_objects[:formats].nil?

      # populate cache if empty
      populate_eventbrite_formats if @eventbrite_objects[:formats].empty?

      # return result
      @eventbrite_objects[:formats][id]
    end

    def populate_eventbrite_formats
      # get formats from Eventbrite
      response = get_json_response(FORMATS_ENDPOINT)
      # process formats
      response['formats'].each do |format|
        # add each item to the cache
        @eventbrite_objects[:formats][format['id']] = format
      end
    rescue Exception => e
      @messages << "populate Eventbrite formats failed with: #{e.message}"
    end

    def get_eventbrite_venue(id)
      # abort on bad input
      return nil if id.nil? or id == 'null'

      # initialize cache
      @eventbrite_objects[:venues] = {} if @eventbrite_objects[:venues].nil?

      # id not in cache
      add_eventbrite_venue id unless @eventbrite_objects[:venues].keys.include? id

      # return from cache
      @eventbrite_objects[:venues][id]
    end

    def add_eventbrite_venue(id)
      # get from query and add to cache if found
      url = format(VENUE_ENDPOINT, id: id)
      venue = get_json_response url
      @eventbrite_objects[:venues][id] = venue unless venue.nil?
    rescue Exception => e
      @messages << "get Eventbrite Venue failed with: #{e.message}"
    end

    def get_eventbrite_category(id)
      # abort on bad input
      return nil if id.nil? or id == 'null'

      # initialize cache
      @eventbrite_objects[:categories] = {} if @eventbrite_objects[:categories].nil?

      # populate cache
      populate_eventbrite_categories if @eventbrite_objects[:categories].empty?

      # finished
      @eventbrite_objects[:categories][id]
    end

    def populate_eventbrite_categories
      # initialise pagination
      has_more_items = true
      url = CATEGORIES_ENDPOINT
      # query until no more pages
      while has_more_items
        # infinite loop guard
        has_more_items = false

        # execute query
        response = get_json_response url

        # process categories
        cats = response['categories']
        unless cats.nil? or !cats.is_a? Array
          cats.each do |cat|
            @eventbrite_objects[:categories][cat['id']] = cat
          end
        end

        # check for next page
        pagination = response['pagination']
        next if pagination.nil?

        has_more_items = pagination['has_more_items']
        page_number = pagination['page_number'] + 1
        url = format(CATEGORIES_PAGE_ENDPOINT, page: page_number)
      end
    rescue Exception => e
      @messages << "get Eventbrite format failed with: #{e.message}"
    end

    def get_eventbrite_subcategory(id, category_id)
      # abort on bad input
      return nil if id.nil? or id == 'null'

      # get category
      category = get_eventbrite_category category_id
      return nil if category.nil?

      # get subcategories from cache
      subcategories = category['subcategories']

      # get subcategories from query
      subcategories = populate_eventbrite_subcategories id, category if subcategories.nil?

      # check for subcategory
      if !subcategories.nil? and subcategories.is_a?(Array)
        subcategories.each { |sub| return sub if sub['id'] == id }
      end

      # not found
      nil
    end

    def populate_eventbrite_subcategories(id, category)
      subcategories = nil
      begin
        url = "#{category['resource_uri']}"
        response = get_json_response url
        # updated cached category
        @eventbrite_objects[:categories][id] = response
        subcategories = response['subcategories']
      rescue Exception => e
        @messages << "get Eventbrite subcategory failed with: #{e.message}"
      end
      subcategories
    end

    def get_eventbrite_organizer(id)
      # abort on bad input
      return nil if id.nil? or id == 'null'

      # initialize cache
      @eventbrite_objects[:organizers] = {} if @eventbrite_objects[:organizers].nil?

      # not in cache
      populate_eventbrite_organizer id unless @eventbrite_objects[:organizers].keys.include? id

      # return from cache
      @eventbrite_objects[:organizers][id]
    end

    def populate_eventbrite_organizer(id)
      # get from query and add to cache if found
      url = format(ORGANIZER_ENDPOINT, id: id)
      organizer = get_json_response url
      # add to cache
      @eventbrite_objects[:organizers][id] = organizer unless organizer.nil?
    rescue Exception => e
      @messages << "get Eventbrite Venue failed with: #{e.message}"
    end

    def get_json_response(url, accept_params = 'application/json')
      response = RestClient::Request.new(method: :get,
                                         url: CGI.unescape_html(url),
                                         verify_ssl: false,
                                         headers: { accept: accept_params,
                                                    authorization: "Bearer #{@token}" }).execute
      # check response
      raise "invalid response code: #{response.code}" unless response.code == 200

      JSON.parse(response.to_str)
    end

    def convert_event_types(input)
      case input.downcase
      when 'conference', 'retreat'
        'meetings_and_conferences'
      when 'class', 'seminar'
        'workshops_and_courses'
      when 'networking', 'expo', 'convention'
        'receptions_and_networking'
      else
        super
      end
    end
  end
end
