# Modified from: http://github.com/koppen/i18n_missing_keys.git

namespace :i18n do
  desc "Find and list translation keys that do not exist in all locales"
  task :missing_keys => :environment do
    finder = I18nMissingKeysFinder.new(I18n.backend)

    reporter = I18nMissingKeysReporter.new(finder)
    reporter.run
  end
end

class I18nMissingKeysReporter

  attr_reader :missing_keys, :all_keys

  def initialize(finder)
    @missing_keys = finder.missing_keys
    @all_keys = finder.all_keys
  end

  def run
    puts ""
    output_missing_keys
  end

  def output_available_locales
    puts "#{I18n.available_locales.size} locales available: #{I18n.available_locales.join(', ')}"
  end

  def output_missing_keys
    missing_keys.keys.sort.each do |key|
      puts "key: '#{key}'"
      I18n.available_locales.excluding(missing_keys[key]).each do |locale|
        puts "#{locale}: '#{I18n.translate(key)}'"
      end

      missing_keys[key].collect(&:to_s).each do |locale|
        puts "#{locale}: *** MISSING ***"
      end
      puts ""
    end
    output_available_locales
    output_unique_key_stats
    puts "#{missing_keys.size} keys missing from one or more locales:"
  end

  def output_unique_key_stats
    number_of_keys = all_keys.size
    puts "#{number_of_keys} #{number_of_keys == 1 ? 'unique key' : 'unique keys'} found."
  end

end
