heroku_name = ask("What do you want to name the Heroku instances?")

gem('administrate')
gem('clockwork')
gem('devise')
gem('delayed_job_active_record')
gem("haml-rails", "~> 1.0")
gem('pg')
gem('rolify')
gem('stripe')
gem('state_machines')
gem('twilio-ruby', '~> 5.20.1')

gem_group :development, :test do
  gem 'dotenv'
  gem 'rspec-rails'
  gem 'timecop'
  gem 'webmock'
  gem 'vcr'
end

gem_group :production, :staging do
  gem 'rails_12factor'
end

run("bundle install")
run("bundle update --bundler")
run("cp config/environments/production.rb config/environments/staging.rb")

environment do 
<<~HAML
  config.generators do |g|
    g.template_engine :haml
  end
HAML
end

# ./.ruby-version
file '.ruby-version', <<~RUBYVERSION
  ruby-2.6.0@#{app_name}
RUBYVERSION

## config/database.yml

remove_file 'config/database.yml'

file 'config/database.yml', <<~DATABASECONFIG
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
DATABASECONFIG

## end config/database.yml

#  Mailgun settings 
mailgunstaging = <<~MAILGUNSTAGING
  ActionMailer::Base.smtp_settings = {
    :port           => ENV['MAILGUN_SMTP_PORT'],
    :address        => ENV['MAILGUN_SMTP_SERVER'],
    :user_name      => ENV['MAILGUN_SMTP_LOGIN'],
    :password       => ENV['MAILGUN_SMTP_PASSWORD'],
    :domain         => '#{app_name}-staging.herokuapp.com',
    :authentication => :plain,
  }
  ActionMailer::Base.delivery_method = :smtp
MAILGUNSTAGING
environment mailgunstaging, env: 'staging'

mailgunproduction = <<~MAILGUNPRODUCTION
  ActionMailer::Base.smtp_settings = {
    :port           => ENV['MAILGUN_SMTP_PORT'],
    :address        => ENV['MAILGUN_SMTP_SERVER'],
    :user_name      => ENV['MAILGUN_SMTP_LOGIN'],
    :password       => ENV['MAILGUN_SMTP_PASSWORD'],
    :domain         => '#{app_name}-production.herokuapp.com',
    :authentication => :plain,
  }
  ActionMailer::Base.delivery_method = :smtp
MAILGUNPRODUCTION
environment mailgunproduction, env: 'production'

# ./config.ru
file 'config.ru', <<~CONFIGRU
  require ::File.expand_path('../config/environment', __FILE__)
  run Rails.application
CONFIGRU

file 'config/clock.rb', <<~CLOCKRB
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
CLOCKRB

# ./Procfile 
file 'Procfile', <<~PROCFILE
  web: bundle exec puma -C config/puma.rb
  worker:  bundle exec rake jobs:work
  clock: bundle exec clockwork config/clock.rb
  release: rake db:migrate
PROCFILE

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

  if yes?("Create Heroku instances?")
    # Heroku setup
    run("heroku create #{heroku_name}-staging -r staging --addons newrelic,mailgun,airbrake,papertrail,heroku-postgresql:hobby-dev")
    run("heroku create #{heroku_name}-production -r production --addons newrelic,mailgun,airbrake,papertrail,heroku-postgresql:hobby-dev")
  end

  # cleanup
  run("rm -rf test/")
  file '.slugignore', <<~SLUGIGNORE
  spec/
  SLUGIGNORE
end

