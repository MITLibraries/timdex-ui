// Configure your import map in config/importmap.rb. Read more: https://github.com/rails/importmap-rails
import "@hotwired/turbo-rails"
import "controllers"
import "loading_spinner"
import "matomo_events"

// Show the progress bar after 200 milliseconds, not the default 500
Turbo.config.drive.progressBarDelay = 200;