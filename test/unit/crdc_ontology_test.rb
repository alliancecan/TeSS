require 'test_helper'

class CRDCOntologyTest < ActiveSupport::TestCase
  test 'should lookup term' do
    term = CRDC::Ontology.instance.lookup('https://www.statcan.gc.ca/en/subjects/standard/crdc/2020v2#RDF1010102')

    assert term
    assert_equal term.label_en, 'Number theory'
    assert_equal term.label_fr, 'Théorie des nombres'

    initial_local = I18n.locale
    I18n.locale = :en
    assert_equal term.preferred_label, 'Number theory'
    I18n.locale = :fr
    assert_equal term.preferred_label, 'Théorie des nombres'
    I18n.locale = initial_local

    path_names = term.path.map(&:label_en)

    assert_equal path_names, ['Number theory', 'Pure mathematics', 'Mathematics and statistics', 'Natural sciences']
  end

  test 'should lookup term by name' do
    term = CRDC::Ontology.instance.lookup_by_name('Bioinorganic chemistry')

    assert term
    assert_equal term.uri, 'https://www.statcan.gc.ca/en/subjects/standard/crdc/2020v2#RDF1040201'
    assert_equal term.preferred_label, 'Bioinorganic chemistry'
    # This ontology doesn't do synonyms
    assert_empty term.synonyms
    assert_empty term.has_exact_synonym
    assert_empty term.has_narrow_synonym
    assert_empty term.has_broad_synonym
  end

  test 'should fetch term subclasses' do
    term = CRDC::Ontology.instance.lookup_by_name('Mathematics and statistics')

    assert_equal 3, term.subclasses.length
    assert_includes term.subclasses.map(&:label), 'Pure mathematics'
    assert_includes term.subclasses.map(&:label), 'Applied mathematics'
    assert_includes term.subclasses.map(&:label), 'Statistics'

    another_term = CRDC::Ontology.instance.lookup_by_name('Number theory')
    assert_empty another_term.subclasses
  end

  test 'should fetch term parent' do
    term = CRDC::Ontology.instance.lookup_by_name('Number theory')

    assert_equal term.parent.label_en, 'Pure mathematics'
    assert_equal term.parent.parent.label_en, 'Mathematics and statistics'
    assert_equal term.parent.parent.parent.label_en, 'Natural sciences' 
    assert_nil term.parent.parent.parent.parent
  end

  test 'should compare term objects by URI' do
    term1 = CRDC::Ontology.instance.lookup_by_name('Number theory')
    term2 = CRDC::Ontology.instance.fetch('https://www.statcan.gc.ca/en/subjects/standard/crdc/2020v2#RDF1010102')

    assert_equal term1.uri, term2.uri
    assert term1 == term2
    assert term1.eql?(term2)
    assert [term1] == [term2]
    assert_empty [term1] - [term2]
  end

  test 'scoped name lookup' do
    skip "Explora: this ontology doesn't have scopes"
  end

  test 'should filter for autocomplete' do
    # Returns maximum of 15
    # Order is "starts_with?" hits are first, then sort by length

    saved_locale = I18n.locale

    I18n.locale = :en
    results = CRDC::Ontology.instance.filter('educ')
    assert_equal results.map(&:preferred_label),
                 ["Education",
                  "Education systems",
                  "Educational policy",
                  "Educational psychology",
                  "Educational counselling",
                  "Education systems, n.e.c.",
                  "Educational technology and computing",
                  "Educational assessment and evaluation",
                  "Educational administration, management and leadership",
                  "Open education",
                  "Other education",
                  "Psychoeducation",
                  "Higher education",
                  "Primary education",
                  "Secondary education"]

    I18n.locale = :fr
    results = CRDC::Ontology.instance.filter('educ')
    assert_equal results.map(&:preferred_label),
                 ["Éducation",
                  "Éducation ouverte",
                  "Éducation préscolaire",
                  "Éducation disciplinaire",
                  "Éducation spécialisée et handicap",
                  "Éducation comparée et interculturelle",
                  "Éducation et vulgarisation en matière d'environnement",
                  "Éducation des adultes et éducation permanente, et éducation communautaire",
                  "Autre éducation",
                  "Psychoéducation",
                  "Systèmes d'éducation",
                  "Économie de l'éducation",
                  "Autre éducation, n.c.a.",
                  "Sociologie de l'éducation",
                  "Psychologie de l'éducation"]

    I18n.locale = saved_locale
  end

end
