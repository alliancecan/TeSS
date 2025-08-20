class ContentProviderPolicy < ScrapedResourcePolicy

  def can_modify_events?
    manage?
  end

end
