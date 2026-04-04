require "test_helper"

class SettingTest < ActiveSupport::TestCase
  test "reads and writes key-value pairs" do
    Setting["test.key"] = "hello"
    assert_equal "hello", Setting["test.key"]
  end

  test "returns nil for missing key" do
    assert_nil Setting["nonexistent.key"]
  end

  test "overwrites existing key" do
    Setting["test.key"] = "first"
    Setting["test.key"] = "second"
    assert_equal "second", Setting["test.key"]
  end

  test "converts value to string" do
    Setting["test.number"] = 42
    assert_equal "42", Setting["test.number"]
  end

  test "validates key presence" do
    setting = Setting.new(key: nil, value: "test")
    assert_not setting.valid?
    assert_includes setting.errors[:key], "can't be blank"
  end

  test "validates key uniqueness" do
    Setting.create!(key: "unique.key", value: "first")
    duplicate = Setting.new(key: "unique.key", value: "second")
    assert_not duplicate.valid?
    assert_includes duplicate.errors[:key], "has already been taken"
  end
end

# == Schema Information
#
# Table name: settings
#
#  id         :integer          not null, primary key
#  key        :string           not null
#  value      :text
#  created_at :datetime         not null
#  updated_at :datetime         not null
#
# Indexes
#
#  index_settings_on_key  (key) UNIQUE
#
