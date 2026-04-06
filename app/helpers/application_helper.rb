module ApplicationHelper
  def listener_stale?
    heartbeat = Setting["listener.heartbeat"]
    return true unless heartbeat

    Time.parse(heartbeat) < 60.seconds.ago
  end

  def qr_code_svg(data)
    RQRCode::QRCode.new(data).as_svg(
      use_path: true,
      viewbox: true,
      shape_rendering: "crispEdges"
    ).html_safe
  end
end
