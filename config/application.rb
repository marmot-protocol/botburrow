require_relative "boot"

require "rails/all"

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module Botburrow
  class Application < Rails::Application
    # Initialize configuration defaults for originally generated Rails version.
    config.load_defaults 8.1

    # Please, add to the `ignore` list any other `lib` subdirectories that do
    # not contain `.rb` files, or that should not be reloaded or eager loaded.
    # Common ones are `templates`, `generators`, or `middleware`, for example.
    config.autoload_lib(ignore: %w[assets tasks])

    config.wnd_socket_path = ENV.fetch("WND_SOCKET_PATH") {
      default_data_dir = if RUBY_PLATFORM.include?("darwin")
        File.join(Dir.home, "Library", "Application Support", "whitenoise-cli")
      else
        File.join(ENV.fetch("XDG_DATA_HOME", File.join(Dir.home, ".local", "share")), "whitenoise-cli")
      end
      data_dir = ENV.fetch("WND_DATA_DIR", default_data_dir)
      mode = ENV.fetch("WND_BUILD_MODE", "release")
      File.join(data_dir, mode, "wnd.sock")
    }
  end
end
