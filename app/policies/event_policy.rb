class EventPolicy < ContentProviderResourcePolicy

  alias_method :edit_report?, :manage?
  alias_method :view_report?, :manage?

end
