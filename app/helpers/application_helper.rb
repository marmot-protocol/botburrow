module ApplicationHelper
  STATUS_COLORS = {
    "running" => "text-success",
    "stopped" => "text-text-faint",
    "starting" => "text-warning",
    "stopping" => "text-warning",
    "error" => "text-danger"
  }.freeze

  def listener_stale?
    heartbeat = Setting["listener.heartbeat"]
    return true unless heartbeat

    Time.parse(heartbeat) < 60.seconds.ago
  end

  def status_color(status)
    STATUS_COLORS[status] || "text-text-muted"
  end

  def bot_avatar(bot, size: 10)
    px = { 10 => "h-10 w-10 text-sm", 12 => "h-12 w-12 text-lg" }[size] || "h-10 w-10 text-sm"

    if bot.picture_url.present?
      image_tag bot.picture_url, alt: bot.name,
        class: "#{px.split.first(2).join(' ')} rounded-full object-cover bg-surface-overlay", loading: "lazy"
    else
      content_tag :div, bot.name.first.upcase,
        class: "flex #{px} items-center justify-center rounded-full bg-surface-overlay font-medium text-text-muted"
    end
  end

  def qr_code_svg(data)
    RQRCode::QRCode.new(data).as_svg(
      use_path: true,
      viewbox: true,
      shape_rendering: "crispEdges"
    ).html_safe
  end
end
