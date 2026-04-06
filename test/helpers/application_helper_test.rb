require "test_helper"

class ApplicationHelperTest < ActionView::TestCase
  test "listener_stale? returns true when no heartbeat exists" do
    assert listener_stale?
  end

  test "listener_stale? returns true when heartbeat is older than 60 seconds" do
    Setting["listener.heartbeat"] = 2.minutes.ago.iso8601
    assert listener_stale?
  end

  test "listener_stale? returns false when heartbeat is recent" do
    Setting["listener.heartbeat"] = Time.current.iso8601
    assert_not listener_stale?
  end

  test "qr_code_svg returns an inline SVG" do
    svg = qr_code_svg("nostr:npub1test")
    assert_includes svg, "<svg"
    assert_includes svg, "</svg>"
  end
end
