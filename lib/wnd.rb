module Wnd
  def self.extract_group_id(mls_group_id)
    return mls_group_id if mls_group_id.is_a?(String)
    return unless mls_group_id.is_a?(Hash)

    bytes = mls_group_id.dig("value", "vec")
    return unless bytes.is_a?(Array)

    bytes.pack("C*").unpack1("H*")
  end
end
