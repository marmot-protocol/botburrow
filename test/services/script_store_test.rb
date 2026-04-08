require "test_helper"

class ScriptStoreTest < ActiveSupport::TestCase
  setup do
    @bot = Bot.create!(name: "StoreBot", npub: SecureRandom.hex(32), status: :running)
  end

  test "reads and writes keys" do
    store = ScriptStore.new(@bot)

    assert_nil store["counter"]

    store["counter"] = 42
    assert_equal 42, store["counter"]
  end

  test "save skips database write when store is clean" do
    store = ScriptStore.new(@bot)

    assert_no_changes -> { @bot.reload.updated_at } do
      store.save!
    end
  end

  test "save persists dirty store to bot script_data" do
    store = ScriptStore.new(@bot)
    store["city"] = "Portland"
    store.save!

    @bot.reload
    assert_equal({ "city" => "Portland" }, JSON.parse(@bot.script_data))
  end

  test "recovers from corrupt JSON in script_data" do
    @bot.update_column(:script_data, "not valid json{{{")

    store = ScriptStore.new(@bot)

    assert_nil store["anything"]
    assert_equal [], store.keys

    # Corrupt store is dirty so save heals it
    store.save!
    @bot.reload
    assert_equal "{}", @bot.script_data
  end

  test "delete removes a key and marks dirty" do
    @bot.update!(script_data: { "a" => 1, "b" => 2 }.to_json)

    store = ScriptStore.new(@bot)
    store.delete("a")
    store.save!

    @bot.reload
    assert_equal({ "b" => 2 }, JSON.parse(@bot.script_data))
  end

  test "keys returns all stored keys" do
    @bot.update!(script_data: { "x" => 1, "y" => 2 }.to_json)

    store = ScriptStore.new(@bot)

    assert_equal %w[x y], store.keys.sort
  end

  test "coerces symbol keys to strings" do
    store = ScriptStore.new(@bot)
    store[:count] = 5

    assert_equal 5, store["count"]
    assert_equal 5, store[:count]
  end
end
