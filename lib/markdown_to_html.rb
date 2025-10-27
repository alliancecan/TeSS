module MarkdownToHtml
  def markdown_to_html(markdown_text, options = {}, renderer_options = {})
    if markdown_text
      options.reverse_merge!(filter_html: true, tables: true, autolink: true)
      renderer_options.
        reverse_merge!(hard_wrap: true, link_attributes: { target: '_blank', rel: 'noopener' })
      Redcarpet::Markdown.new(Redcarpet::Render::HTML.new(renderer_options), options).
        render(markdown_text).html_safe
    else
      ''
    end
  end
end
