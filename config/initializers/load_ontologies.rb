require_relative '../../app/ontologies/ontology'
require_relative '../../app/ontologies/ontology_term'
require_relative '../../app/ontologies/crdc/term'
require_relative '../../app/ontologies/crdc/ontology'

OBO = RDF::Vocabulary.new('http://www.geneontology.org/formats/oboInOwl#')
EDAM = RDF::Vocabulary.new('http://edamontology.org/')
CRDC::Ontology.instance.load
