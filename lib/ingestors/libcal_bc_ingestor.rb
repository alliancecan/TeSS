require 'open-uri'
require 'csv'

module Ingestors
  class LibcalBcIngestor < LibcalIngestor
    def self.config
      {
        key: 'libcal_bc_event',
        title: 'Libcal Events API (BC)',
        category: :events
      }
    end

    private

    def handle_location_and_times(event, url, attr)
      # Pulling out the NL specific stuff so it can be subclassed
      event.set_default_times
      event.venue = attr.fetch('location', '')

      event.timezone = 'Pacific Time (US & Canada)'
      event.start = attr.fetch('startdt', '')
      event.end = attr.fetch('enddt', '')

      # No timezone present in output, so we assume the times are local
      if event.start.present?
        event.start = Time.zone.parse(event.start)&.change(zone: event.timezone)
      end
      if event.end.present?
        event.end = Time.zone.parse(event.end)&.change(zone: event.timezone)
      end
    end
  end
end
