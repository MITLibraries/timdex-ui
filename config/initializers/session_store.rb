# Be sure to restart your server when you modify this file.
# Note, you must set `SECRET_KEY_BASE` environment variable before running the application or sessions will not work.
# Changing `SECRET_KEY_BASE` will invalidate all existing sessions.
# You can generate a new secret key by running `bin/rails secret` command.
Rails.application.config.session_store :cookie_store, key: '_use_session', secure: false, same_site: :strict
