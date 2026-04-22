class ContentProviderPolicy < ScrapedResourcePolicy

  def can_modify_events?
    manage?
  end

  def can_modify_materials?
    manage?
  end

end
