# The helper for Content Providers
module ContentProvidersHelper
  def content_providers_info_button
    info_button(t('providers.info_button_header',
                  site: TeSS::Config.site['title_short']), hide_text: true) do
      content_providers_info
    end
  end

  def content_providers_info_box(hide_text = true)
    info_box(t('providers.info_button_header',
               site: TeSS::Config.site['title_short'])) do
      content_providers_info
    end
  end

  def content_providers_info
    I18n.t('providers.info')
  end

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
