gem('devise')
gem('haml')
gem('delayed_job_active_record')
gem('twilio-ruby', '~> 5.20.1')
gem('stripe')
gem('administrate')
gem('state_machines')
gem('pg')

gem_group :development, :test do
  gem 'rspec-rails'
  gem 'dotenv'
end

gem_group :production, :staging do
  gem 'rails_12factor'
end

run("bundle install")
run("bundle update --bundler")

## config/database.yml

remove_file 'config/database.yml'

file 'config/database.yml', <<-CODE

default: &default
  adapter: postgresql
  encoding: unicode
  pool: <%= ENV.fetch("RAILS_MAX_THREADS") { 5 } %>

development:
  username: #{app_name}
  <<: *default
  database: #{app_name}_development

test:
  <<: *default
  database: #{app_name}_test
  username: #{app_name}
CODE

## end config/database.yml

rails_command "db:create:all"

after_bundle do
  generate('devise:install')
  generate('devise user')
  generate('administrate:install')
  generate('delayed_job:active_record')

  rails_command('db:migrate')

  git :init
  git add: "."
  git commit: %Q{ -m 'Initial commit' }
end
