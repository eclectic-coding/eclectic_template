# Template Name: Eclectic - Tailwind CSS
# Author: Chuck Smith, https://chucksmith.dev
# Credit: Andy Leverenz, https://web-crunch.com
# Instructions: $ rails new myapp -d <postgresql, mysql, sqlite3> -m template.rb

def source_paths
  [File.expand_path(File.dirname(__FILE__))]
end

def add_gems
  gem "devise", "~> 4.7", ">= 4.7.2"
  gem "friendly_id", "~> 5.3"
  gem "image_processing"
  gem "sidekiq", "~> 6.1", ">= 6.1.1"
  gem "name_of_person", "~> 1.1", ">= 1.1.1"

  gem_group :development, :test do
    gem "database_cleaner"
    gem "factory_bot_rails", git: "http://github.com/thoughtbot/factory_bot_rails"
    gem "rspec-rails"
  end

  gem_group :development do
    gem "fuubar"
    gem "guard"
    gem "guard-rspec"
    gem "rubocop"
    gem "rubocop-rails", require: false
    gem "rubocop-rspec"
  end

  gem_group :test do
    gem 'simplecov', require: false
  end
end

def add_testing
  generate "rspec:install"

  directory "spec", force: true

  run "rm -r test" if Dir.exist?("test")

  copy_file "config/webpacker.yml", force: true
  copy_file ".rspec", force: true
  copy_file ".rubocop.yml"
  copy_file ".simplecov"
  copy_file "Guardfile"
end

def add_active_storage
  rails_command 'active_storage:install'

  environment "config.active_storage.service = :local",
              env: "development"

end

def stop_spring
  run "spring stop"
end

def add_users
  # Install Devise
  generate "devise:install"

  # Configure Devise
  environment "config.action_mailer.default_url_options = { host: 'localhost', port: 3000 }",
              env: "development"

  route "root to: 'static#home'"

  # Create Devise User
  generate :devise, "User", "first_name", "last_name", "admin:boolean"

  # set admin boolean to false by default
  in_root do
    migration = Dir.glob("db/migrate/*").max_by { |f| File.mtime(f) }
    gsub_file migration, /:admin/, ":admin, default: false"
  end

  # name_of_person gem & active storage attachment
  append_to_file("app/models/user.rb", "\n\nhas_person_name\nhas_one_attached :avatar\n", after: ":recoverable, :rememberable, :validatable")
end

def copy_templates
  directory "app", force: true
end

def add_tailwind
  run "yarn add tailwindcss"
  run "yarn add @fullhuman/postcss-purgecss"

  run "mkdir -p app/javascript/stylesheets"

  append_to_file("app/javascript/packs/application.js", 'import "stylesheets/application"' + "\n")
  inject_into_file("./postcss.config.js",
                   "let tailwindcss = require('tailwindcss');\n", before: "module.exports")
  inject_into_file("./postcss.config.js", "\n    tailwindcss('./app/javascript/stylesheets/tailwind.config.js'),", after: "plugins: [")

  run "mkdir -p app/javascript/stylesheets/components"
end

def copy_postcss_config
  run "rm postcss.config.js"
  copy_file "postcss.config.js"
end

def add_fontawesome
  run "yarn add @fortawesome/fontawesome-free"

  # # add reference to fontawesome-free to application.scss
  inject_into_file 'app/javascript/stylesheets/application.scss' do
    <<~EOF
      @import '~@fortawesome/fontawesome-free';
    EOF
  end


  # add require of css/application.scss && import of fontawesome-free to application.js
  inject_into_file 'app/javascript/packs/application.js' do
    <<~EOF
      require("stylesheets/application.scss")
      import "@fortawesome/fontawesome-free/js/all"
    EOF
  end
end

def add_stimulus
  rails_command "webpacker:install:stimulus"
end


# Remove Application CSS
def remove_app_css
  remove_file "app/assets/stylesheets/application.css"
end

def add_sidekiq
  environment "config.active_job.queue_adapter = :sidekiq"

  insert_into_file "config/routes.rb",
                   "require 'sidekiq/web'\n\n",
                   before: "Rails.application.routes.draw do"

  content = <<-RUBY
    authenticate :user, lambda { |u| u.admin? } do
      mount Sidekiq::Web => '/sidekiq'
    end
  RUBY
  insert_into_file "config/routes.rb", "#{content}\n\n", after: "Rails.application.routes.draw do\n"
end

def add_foreman
  copy_file "Procfile"
end

def add_friendly_id
  generate "friendly_id"
end

def add_stimulus_navbar
  run "yarn add tailwindcss-stimulus-components"

  # inject

end

# Main setup
source_paths

add_gems

after_bundle do
  stop_spring
  add_testing
  add_active_storage
  add_users
  remove_app_css
  add_sidekiq
  add_foreman
  copy_templates
  add_tailwind
  add_fontawesome
  add_stimulus
  add_friendly_id
  copy_postcss_config
  add_stimulus_navbar

  # Migrate
  rails_command "db:create"
  rails_command "db:migrate"

  git :init
  git add: "."
  git commit: %Q{ -m "Initial commit" }

  say
  say "Eclectic app successfully created! 👍", :green
  say
  say "Switch to your app by running:"
  say "$ cd #{app_name}", :yellow
  say
  say "Then run:"
  say "$ rails server", :green
end
