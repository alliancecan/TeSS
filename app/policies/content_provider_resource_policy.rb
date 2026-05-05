# A policy specific to things that have been scraped. Events and Materials

class ContentProviderResourcePolicy < ScrapedResourcePolicy

  def manage?
    # Need to be a bit more restrictive
    # Here we pretty much have everything as the superclass class, except for allowing
    # the owner
    @user &&
      (@user.is_admin? ||
       (request_is_api?(@request) && @user.has_role?(:scraper_user)) ||
       @user.is_curator? ||
       is_content_provider_editor?)
  end
  alias_method :new?, :manage?
  alias_method :create?, :manage?
  alias_method :edit?, :manage?
  alias_method :update?, :manage?
  alias_method :clone?, :manage?
end
