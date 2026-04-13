class OntologyTermLink < ApplicationRecord
  ONTOLOGIES = [Edam::Ontology.instance,
                CRDC::Ontology.instance]

  belongs_to :resource, polymorphic: true

  def ontology_term
    ontology.lookup(term_uri)
  end

  def ontology
    @ontology ||= ONTOLOGIES.find { |ontology| ontology.term_uri_matches?(term_uri) }
  end

end
