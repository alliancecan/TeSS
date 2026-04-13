module CRDC
  class Term < ::OntologyTerm
    alias_method :code, :uri

    attr_reader :parent_uri, :label_en, :subclass_uris
    attr_accessor :label_fr, :path

    def initialize(ontology,
                   uri: nil,
                   label_en: nil,
                   parent_uri: nil)
      # Complications because of bilingualism
      raise ArgumentError("uri required") unless uri

      @ontology = ontology
      @uri = uri

      # We don't typically load french before english
      @label_store = { en: label_en }

      # We don't typically have access to parent object, just URI
      @parent_uri = parent_uri

      @subclass_uris = []

      # For quicker filtering
      @normalized = { en: normalize_label(label_en)}

      @path = []
    end

    def parent
      ontology.lookup(parent_uri)
    end

    def subclasses
      subclass_uris.map {|uri| ontology.lookup(uri) }
    end

    def label_en
      @label_store[:en]
    end

    def label_fr=(label)
      @label_store[:fr] = label
      @normalized[:fr] = normalize_label(label)
    end

    def label_fr
      @label_store[:fr]
    end

    def label
      @label_store[I18n.locale]
    end
    alias_method :preferred_label, :label

    def labels
      return @label_store
    end

    def normalize_label(label)
      I18n.transliterate(label.downcase.strip)
    end

    def matches?(string, locale: :en, match_method: :'include?')
      # methods are ':include?' or ':starts_with?'
      return @normalized[locale].send(match_method, string)
    end

    def multilingual?
      true
    end

    def synonyms
      # TODO: maybe figure this out better?
      # (e.g., if level 3-4 classification, maybe level 2 is a synonym)
      []
    end
    alias_method :has_exact_synonym, :synonyms
    alias_method :has_narrow_synonym, :synonyms
    alias_method :has_broad_synonym, :synonyms

    def deprecated?
      false
    end

  end
end
