require "test_helper"

class BotTest < ActiveSupport::TestCase
  include ActionCable::TestHelper
  test "bot requires a name" do
    bot = Bot.new(npub: "npub1unique00000000000000000000000000000000000000000000000000")
    assert_not bot.valid?
    assert_includes bot.errors[:name], "can't be blank"
  end

  test "bot requires an npub" do
    bot = Bot.new(name: "TestBot")
    assert_not bot.valid?
    assert_includes bot.errors[:npub], "can't be blank"
  end

  test "bot npub must be unique" do
    existing = bots(:relay_bot)
    bot = Bot.new(name: "Duplicate", npub: existing.npub)
    assert_not bot.valid?
    assert_includes bot.errors[:npub], "has already been taken"
  end

  test "bot name is stripped of whitespace" do
    bot = Bot.new(name: "  SpaceyBot  ", npub: "npub1spacey00000000000000000000000000000000000000000000000000")
    assert_equal "SpaceyBot", bot.name
  end

  test "bot defaults to stopped status" do
    bot = Bot.new(name: "NewBot", npub: "npub1newbot00000000000000000000000000000000000000000000000000")
    assert_equal "stopped", bot.status
  end

  test "bot supports all five status states" do
    bot = bots(:relay_bot)

    bot.stopped!
    assert bot.stopped?

    bot.starting!
    assert bot.starting?

    bot.running!
    assert bot.running?

    bot.stopping!
    assert bot.stopping?

    bot.error!
    assert bot.error?
  end

  test "destroying a bot destroys its commands" do
    bot = bots(:relay_bot)
    command_count = bot.commands.count
    assert command_count > 0

    assert_difference "Command.count", -command_count do
      bot.destroy
    end
  end

  test "broadcasts replace when status changes" do
    bot = bots(:relay_bot)

    assert_broadcasts "bots", 1 do
      bot.update!(status: :running)
    end
  end

  test "does not broadcast when non-status attributes change" do
    bot = bots(:relay_bot)

    assert_no_broadcasts "bots" do
      bot.update!(name: "RenamedBot")
    end
  end
end

# == Schema Information
#
# Table name: bots
#
#  id                      :integer          not null, primary key
#  auto_accept_invitations :boolean          default(TRUE), not null
#  description             :text
#  error_message           :text
#  name                    :string           not null
#  npub                    :string           not null
#  status                  :integer          default("stopped"), not null
#  created_at              :datetime         not null
#  updated_at              :datetime         not null
#
# Indexes
#
#  index_bots_on_npub  (npub) UNIQUE
#
