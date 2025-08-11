require 'open-uri'
require 'csv'

module Ingestors
  class LibcalOnIngestor < LibcalIngestor
    TIMEZONE = 'Eastern Time (US & Canada)'
    CONVERT_TIMES_TO_UTC = true

    def self.config
      {
        key: 'libcal_on_event',
        title: 'Libcal Events API (ON)',
        category: :events
      }
    end
  end
end
