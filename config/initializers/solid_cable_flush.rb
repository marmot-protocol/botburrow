# solid_cable 4 writes broadcasts from a background thread in batches. Flush
# that batch before the process exits so broadcasts sent just before exit
# (BotListener shutdown, runner tasks) still reach subscribers.
at_exit do
  if defined?(ActionCable::SubscriptionAdapter::SolidCable)
    pubsub = ActionCable.server.pubsub
    pubsub.shutdown if pubsub.is_a?(ActionCable::SubscriptionAdapter::SolidCable)
  end
end
