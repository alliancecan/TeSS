module CRDC
  class Ontology < ::Ontology
    include Singleton

    URI_PREFIX = 'https://www.statcan.gc.ca/en/subjects/standard/crdc/2020v2#'

    def initialize
      @filename_en = 'crdc/CRDC-CCRD-2020-FOR-DDR-StructureV2-eng.csv'
      @filename_fr = 'crdc/CRDC-CCRD-2020-FOR-DDR-StructureV2-fra.csv'
      @term_class = OntologyTerm
      @term_cache = {}
      @query_cache = {}
      @term_graph = {}
    end

    def uri
      # Narrator's voice: "It was not a URI"
      "https://www.statcan.gc.ca/en/subjects/standard/crdc/2020v2"
    end

    def lookup(uri)
      @term_graph[uri]
    end
    alias_method :fetch, :lookup

    def filter(string, locale=:en, match_method: :include, limit: 10)
      method = if match_method == :include
                 :'include?'
               elsif match_method == :starts_with
                 :'starts_with?'
               else
                 raise ArgumentError,new('Uncognized search method')
               end

      normalized_string = normalize_label(string)

      @term_graph.values.
        select { |term| term.matches?(normalized_string, locale: locale, match_method: method) }.
        sort_by { |term| 1 }.  # todo
        slice(1, limit)
    end

    def all_topics
      @term_graph.values
    end

    def all_operations
      []
    end

    def lookup_by_name(name)
      @term_graph.values.find { |term| term.label == name }
    end

    def scoped_lookup_by_name(name, subset = :_)
      # This "ontology" doesn't have branches ...
      lookup_by_name(name)
    end
    alias_method :scoped_lookup_by_name_or_synonym, :scoped_lookup_by_name

    def base_path
      File.join(Rails.root, 'config', 'ontologies')
    end

    def cache_path
      "#{base_path}--CRDC-2020-v2.0.cache"
    end

    def normalize_label(label)
      I18n.transliterate(label.downcase.strip)
    end

    def code_to_uri(code)
      "#{URI_PREFIX}#{code}"
    end

    def load
      # Load English first, then load French, then set paths
      @term_graph = {}
      CSV.foreach(File.join(base_path, @filename_en), 'r', headers: true) do |row|
        term = row.to_h
        uri = code_to_uri(term['Code'])
        label = term['Class title']
        @term_graph[uri] = CRDC::Term.new(self,
                                          uri: uri,
                                          label_en: label,
                                          parent_uri: code_to_uri(term['Parent']))
      end

      # Assumption: en/fr have the same number of terms
      CSV.foreach(File.join(base_path, @filename_fr), 'r', headers: true) do |row|
        term = row.to_h
        uri = code_to_uri(term['Code'])
        label = term['Titres de classes']
        @term_graph[uri].label_fr = label
      end

      @term_graph.each do |uri, term|
        term.path = [term]
        parent = @term_graph[term.parent_uri]
        parent.subclass_uris << uri if parent

        while parent
          term.path << parent
          parent = @term_graph[parent.parent_uri]
        end
      end

      return @term_graph
    end

  end

  def topics
    CRDC.ontology.instaince.all_topics
  end

end
