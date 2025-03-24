class ApplicationController < ActionController::Base
  # This will only protect CONFIGURED routes, but also could be put on just certain
  # controllers, it does not need to be in ApplicationController
  before_action do |controller|
    BotChallengePage::BotChallengePageController.bot_challenge_enforce_filter(controller)
  end

  helper Mitlibraries::Theme::Engine.helpers
end
