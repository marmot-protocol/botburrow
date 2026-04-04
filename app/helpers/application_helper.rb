module ApplicationHelper
  def listener_stale?
    heartbeat = Setting["listener.heartbeat"]
    return true unless heartbeat

    Time.parse(heartbeat) < 60.seconds.ago
  end
end
