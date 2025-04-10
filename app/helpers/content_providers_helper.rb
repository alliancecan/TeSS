# The helper for Content Providers
module ContentProvidersHelper
  CONTENT_PROVIDERS_INFO = I18n.t 'providers.info'

  def carousel_content_providers
    provider_ids = TeSS::Config.site.dig('home_page', 'featured_providers')
    provider_ids ||= ContentProvider.from_verified_users.
                       where.not(image_file_size: nil).
                       pluck(:id)
    # Randomly select the desired number of providers ...
    provider_ids = provider_ids.sample(TeSS::Config.site['n_provider_ids'])
    return if provider_ids.blank?

    ContentProvider.where(id: provider_ids)
  end
end
