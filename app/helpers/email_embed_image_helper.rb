module EmailEmbedImageHelper
  def email_image_tag(image, **options)
    # Image is an attachment. See:
    # https://stackoverflow.com/questions/4918414/what-is-the-right-way-to-embed-image-into-email-using-rails
    attachments[image] = File.read(Rails.root.join("app/assets/images/#{image}"))
    image_tag attachments[image].url, **options
  end
end