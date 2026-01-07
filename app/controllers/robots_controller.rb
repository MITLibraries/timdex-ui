class RobotsController < ApplicationController
  layout false

  def robots
    body = if ENV.fetch('ROBOTS_ENV', '') == 'production'
      File.read(Rails.root.join('config','robots-production.txt'))
    else
      File.read(Rails.root.join('config','robots-nonproduction.txt'))
    end

    headers['cache-control'] = "public, max-age=#{1.week.seconds.to_i}"
    render :plain => body, :layout => false, :content_type => 'text/plain'
  end
end
