class CollectionPolicy < ResourcePolicy

  def new?
    # xadmin/owner/currator/scraper or works with a content provider
    @user &&
      (@user.is_admin? ||
       @user.is_curator? ||
       (request_is_api?(@request) && @user.has_role?(:scraper_user)) ||
       is_editor_of_a_content_provider?)
  end
  alias_method :create?, :new?

  def update?
    super || @record.collaborator?(@user)
  end

  def show?
    (!@record.from_unverified_or_rejected? && @record.public?) || update?
  end

  def curate?
    update?
  end

  def update_curation?
    curate?
  end

  class Scope < Scope
    def resolve
      Collection.visible_by(@user)
    end
  end

  private

  def is_editor_of_a_content_provider?
    ContentProvider.where(user: @user).first ||
      ContentProvider.includes(:editors).\
        any? { |content_provider| content_provider.editors.include?(@user) }
  end
end
