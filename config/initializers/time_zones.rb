# config/initializers/time_zones.rb

# Add some timezone mappings that will be in future versions of rails
if !ActiveSupport::TimeZone::MAPPING.key?('Pacific Time (Canada)')
  ActiveSupport::TimeZone::MAPPING['Pacific Time (Canada)'] = \
    "America/Vancouver"
end

if !ActiveSupport::TimeZone::MAPPING.key?('Alberta')
  ActiveSupport::TimeZone::MAPPING['Alberta'] = "America/Edmonton"
end

if !ActiveSupport::TimeZone::MAPPING.key?('Manitoba')
  ActiveSupport::TimeZone::MAPPING['Manitoba'] = "America/Winnipeg"
end

# Clear the cached array
ActiveSupport::TimeZone.clear
