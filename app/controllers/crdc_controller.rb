# The controller for actions related to the EDAM ontology
class CRDCController < ApplicationController

  skip_before_action :authenticate_user!, :authenticate_user_from_token!

  def topics
    @terms = CRDC::Ontology.instance.filter(filter_param, locale: I18n.locale)

    render 'index', format: :json
  end

  private

  def filter_param
    if params[:filter].present?
      params[:filter]
    elsif params[:q].present?
      params[:q].chomp('*') # Chop off the * appended automatically by the autocompleter
    end
  end

end
