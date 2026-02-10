require 'open-uri'
require 'csv'

module Ingestors
  module Explora
    class LibcalBcIngestor < LibcalIngestor
      TIMEZONE = 'Pacific Time (US & Canada)'
      CONVERT_TIMES_TO_UTC = true

      def self.config
        {
          key: 'libcal_bc_event',
          title: 'Libcal Events API (BC)',
          category: :events
        }
      end
    end
  end
end
