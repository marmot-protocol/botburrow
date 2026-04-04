class ApplicationController < ActionController::Base
  include Authentication
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  # Changes to the importmap will invalidate the etag for HTML responses
  stale_when_importmap_changes

  rescue_from Wnd::Error, with: :wnd_unavailable

  private

  def wnd_unavailable(exception)
    redirect_back fallback_location: root_path, alert: "Cannot reach wnd: #{exception.message}"
  end
end
