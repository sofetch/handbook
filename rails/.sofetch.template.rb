gem('devise')
gem("haml-rails", "~> 1.0")
gem('delayed_job_active_record')
gem('twilio-ruby', '~> 5.20.1')
gem('stripe')
gem('administrate')
gem('state_machines')
gem('pg')
gem('clockwork')

gem_group :development, :test do
  gem 'rspec-rails'
  gem 'dotenv'
end

gem_group :production, :staging do
  gem 'rails_12factor'
end

run("bundle install")
run("bundle update --bundler")

environment do 
<<~CODE
  config.generators do |g|
    g.template_engine :haml
  end
CODE
end

# ./.ruby-version
file '.ruby-version', <<~CODE
  ruby-2.6.0@#{app_name}
CODE

## config/database.yml

remove_file 'config/database.yml'

file 'config/database.yml', <<~CODE
  default: &default
    adapter: postgresql
    encoding: unicode
    pool: <%= ENV.fetch("RAILS_MAX_THREADS") { 5 } %>

  development:
    username: cgrusden
    <<: *default
    database: #{app_name}_development

  test:
    <<: *default
    database: #{app_name}_test
    username: cgrusden
CODE

## end config/database.yml

# ./config.ru
file 'config.ru', <<~CODE
  require ::File.expand_path('../config/environment', __FILE__)
  run Rails.application
CODE

file 'config/clock.rb', <<~CODE
  require 'clockwork'
  require './config/boot'
  require './config/environment'

  module Clockwork
    #handler do |job|
    #  puts "Running <job>"
    #end

    #every(30.minutes, 'Whatever Job', at: ['**:00', '**:30']) do 
      # Whatever code to run every 30 minutes
  end
CODE

# ./Procfile 
file 'Procfile', <<~CODE
  web: bundle exec puma -C config/puma.rb
  worker:  bundle exec rake jobs:work
  clock: bundle exec clockwork config/clock.rb
  release: rake db:migrate
CODE

rails_command "db:create:all"

after_bundle do

  # before:db_migrate
  generate('devise:install')
  generate('devise user')
  generate('delayed_job:active_record')
  # end before:db_migrate

  rails_command('db:migrate')

  # after:db_migrate
  generate('administrate:install')
  # end after:db_migrate


  # Git setup
  git :init
  git add: "."
  git commit: %Q{ -m 'Initial commit' }

  # Heroku setup
  heroku_name = ask("What do you want to name the Heroku instances?")
  run("heroku create #{heroku_name}-staging -r staging --addons newrelic,mailgun,airbrake,papertrail,heroku-postgresql:hobby-dev")
  run("heroku create #{heroku_name}-production -r production --addons newrelic,mailgun,airbrake,papertrail,heroku-postgresql:hobby-dev")
end

