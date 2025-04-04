# Modified from: http://github.com/koppen/i18n_missing_keys.git

class I18nMissingKeysFinder

  # These crash the I18n.t function
  FATAL_KEYS = [
    'i18n.plural.rule',
    'number.nth.ordinalized',
    'number.nth.ordinals'
  ].freeze

  def initialize(backend)
    @backend = backend
    self.load_config
    self.load_translations
  end

  def missing_keys
    @missing_keys ||= run
  end

  def run
    @missing_keys = {}
    all_keys.each do |key|

      I18n.available_locales.each do |locale|

        skip = false
        ls = locale.to_s
        if !@ignore_keys[ls].nil?
          @ignore_keys[ls].each do |re|
            if key.match(re)
              skip = true
              break
            end
          end
        end

        if skip == false && !key_exists?(key, locale)
          if @missing_keys[key]
            missing_keys[key] << locale
          else
            @missing_keys[key] = [locale]
          end
        end
      end
    end

    return @missing_keys
  end

  # Returns an array with all keys from all locales
  def all_keys
    @all_keys ||= I18n.backend.send(:translations).collect do |check_locale, translations|
      collect_keys([], translations).sort
    end.flatten.uniq
  end

  def load_translations
    # Make sure we’ve loaded the translations
    I18n.backend.send(:init_translations)
  end

  def load_config
    @ignore_keys = if ENV['NO_IGNORE_MISSING_KEYS']
                     {}
                   else
                     YAML.load_file(File.join(Rails.root, 'config', 'i18n_missing_keys_ignore.yml'))
                   end
    # Include keys that cause I18n.t to crash
    I18n.available_locales.map(&:to_s).each do |locale|
      @ignore_keys[locale] ||= []
      @ignore_keys[locale] += FATAL_KEYS
    end
  rescue => e
    STDERR.puts "No i18n_missing_keys_ignore.yml config file."
  end

  def collect_keys(scope, translations)
    full_keys = []
    translations.to_a.each do |key, translations|
      next if translations.nil?

      new_scope = scope.dup << key
      if translations.is_a?(Hash)
        full_keys += collect_keys(new_scope, translations)
      else
        full_keys << new_scope.join('.')
      end
    end
    return full_keys
  end

  # Returns true if key exists in the given locale
  def key_exists?(key, locale)
    I18n.locale = locale
    a = I18n.translate(key, raise: true, fallback: false)
    return true
  rescue I18n::MissingInterpolationArgument
    return true
  rescue I18n::MissingTranslationData
    return false
  end

end
