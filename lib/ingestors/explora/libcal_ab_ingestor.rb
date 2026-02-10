require 'open-uri'
require 'csv'

module Ingestors
  module Explora
    class LibcalAbIngestor < LibcalIngestor
      TIMEZONE = 'Mountain Time (US & Canada)'
      CONVERT_TIMES_TO_UTC = true

      def self.config
        {
          key: 'libcal_ab_event',
          title: 'Libcal Events API (AB)',
          category: :events
        }
      end
    end
  end
end
