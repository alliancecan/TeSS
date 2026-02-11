require 'airrecord'

module Ingestors
  module Explora
    class CrdcnAirtableIngestor < Ingestor
      # Note: URL isn't used when going through airrecord API
      # Note: pagonation and max records read is not currently hear

      # Maybe this could be set by the ingested records?
      TIMEZONE = 'Eastern Time (US & Canada)'

      def self.config
        {
          key: 'crdcn_airtable',
          title: 'CRDCN Airtable',
          category: :events
        }
      end

      def read(url)
        process_crdcn_airtable(url)
      rescue Exception => e
        @messages << "#{self.class.name} failed with: #{e.message}"
      ensure
        nil
      end

      private

      def parsed_token
        @parsed_token ||= JSON.parse(@token)
      end

      def api_key
        @api_key ||= parsed_token['api_key']
      end

      def base_id
        @base_id ||= parsed_token['base_id']
      end

      def table_id
        @table_id ||= parsed_token['table_id']
      end

      def process_crdcn_airtable(url)
        @table = Airrecord.table(api_key, base_id, table_id)

        @records = @table.all

        process_data
      end

      def process_data
        @records.each do |item|
          event = item_to_event(item)
          add_event(event) if event.present?
        end
      end

      def item_to_event(item)
        event = OpenStruct.new
        event.external_id = item['Event ID']
        event.title = item['Title']
        event.description = item['Content']
        event.url = item['Permalink']
        event.language = item['Event language']&.first&.slice(0, 2)
        event.presence = (item['Delivery method'] == 'Virtual') ? 'online' : 'onsite'

        event.start = Time.parse(item['Event date/time'])
        duration = item['Duration'].to_i
        event.end = event.start + duration.seconds
        event.timezone = TIMEZONE

        return event
      end

    end
  end
end
