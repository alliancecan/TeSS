module Ingestors::Concerns::NormalizeTimezone
  private

  def normalize_timezone(input)
    # Common Canadian time zones seen in the wild.
    # These don't appear in ActiveSupport::TimeZone::MAPPING
    # TODO: put this in Ingestor or in WithTimezone concern
    # TODO: refactor similar code in DracIcalIngestor
    case input
    when /Vancouver/
      return 'Pacific Time (US & Canada)'
    when /Edmonton/
      return 'Mountain Time (US & Canada)'
    when /Toronto/, /Montreal/
      return 'Eastern Time (US & Canada)'
    when /Moncton/
      return 'Atlantic Time (Canada)'
    when /Winnipeg/
      return 'Central Time (US & Canada)'
    end

    input
  end
end
