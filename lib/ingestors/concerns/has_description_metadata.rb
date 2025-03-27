module Ingestors::Concerns::HasDescriptionMetadata

  LANGUAGE_MAP = {
    :en => :en,
    'en' => :en,
    'english' => :en,
    'anglais' => :en,

    :fr => :fr,
    'fr' => :fr,
    'french' => :fr,
    'francais' => :fr,
  }.freeze

  private

  def process_description_metadata(description, title, event)
    # TODO: should be controlled by a flag too?
    # Currently only find keywords if not previously set
    enable_auto_keywords = event.keywords.blank?

    # Could be HTML?
    # TODO: is there something more elegant?
    text_description = Nokogiri::HTML(description.to_s.gsub('<br>', "\n")).text

    key_values = parse_description_metadata(text_description)

    key_values.each do |key, value|
      case key
      when :language
        # To do transform/validate
        lang_key = if value.is_a?(String)
                     I18n.transliterate(value).downcase
                   else
                     value
                   end
        language = LANGUAGE_MAP[lang_key]
        event.language = language if language
      when :presence
        # Model validation will catch this ...
        event.presence = value&.downcase
      when :url
        # Model validation will catch this ...
        event.url = value
      when :keywords
        if enable_auto_keywords
          enable_auto_keywords = false
          value = value&.split(',').map {|v| v.strip.capitalize}
          event.keywords = value
        end
      end
    end

    auto_detect_keywords(text_description, title, event) if enable_auto_keywords

  end

  def parse_description_metadata(text_description)
    return {} unless text_description

    # We want to look for metadata in final "paragraph" of description
    last_paragraph = text_description.split(/\n\n/).last

    # Turn it into a hash ...
    key_values = last_paragraph.split(/\n/).
                                collect {|line| line.split(':', 2) }

    return {} unless key_values

    # Reject if there are any lines without a key/value pair
    return {} if key_values.any? { |key_value| key_value.length < 2 }

    # Clean and make hash
    parsed = key_values.map do |kv|
      key = kv[0].strip.downcase.to_sym
      value = kv[1].strip
      [key, value]
    end.to_h

    return parsed
  end

  def auto_detect_keywords(description, title, event)
    # TODO: possibly anything would be better than this -- maybe AI?

    # Mush it all together
    text = " #{title} #{description} ".gsub(/\W+/, ' ').downcase

    keywords = Set.new
    if text =~ / humanitites /
      keywords << 'Humanities'
    end
    if text =~ / social science/
      keywords << 'Social Sciences'
    end
    if text =~ /physics /
      keywords << ' Physics '
    end
    if text =~ /chem/
      keywords << 'Chemistry'
    end
    if text =~ / gpu / || text =~ / nvidia / || text =~ / cuda /
      keywords << 'GPU'
      keywords << 'HPC'
    end
    if text =~ / machine learning /|| text =~ / tensorflow / ||
       text =~ /torch / || text =~ / llm / || text =~ / chatgpt / ||
       text =~ /generative/
      keywords << 'Machine Learning'
      keywords << 'AI'
    end
    if text =~ /new *user/
      keywords << 'Introductory'
      keywords << 'New User'
    end
    if text =~ / big *data / || text =~ / spark /
      keywords << 'Big Data'
      keywords << 'Data Analytics'
    end
    if text =~ / python /
      keywords << 'Python'
      keywords << 'Programming'
    end
    if text =~ / visualiz/ || text =~ / paraview /
      keywords << 'Visualization'
    end
   if text =~ / git /
      keywords << 'Git'
      keywords << 'Programming'
    end
    if text =~ / julia /
      keywords << 'Julia'
      keywords << 'Programming'
    end

    if text =~ / data *frame / || text =~ / pandas /
      keywords << 'Statistics'
      keywords << 'Data Analysis'
    end

    if text =~ / fortran /
      keywords << 'Programming'
    end

    if text =~ /openmp/ || text =~ / mpi /
      keywords << 'Programming'
      keywords << 'Parallel'
      keywords << 'HPC'
    end

    if text =~ / emacs / || text =~ / vim / || text =~ / vscode / || text =~ / nano /
      keywords << 'Editor'
    end

    if text =~ / bash / || text =~ / shell / || text =~ / command *line /
      keywords << 'Shell'
    end

    event.keywords = keywords.to_a if keywords.present?
  end

end
