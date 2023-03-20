require "fileutils"
require "shellwords"



# Copied from: https://github.com/mattbrictson/rails-template
# Add this template directory to source_paths so that Thor actions like
# copy_file and template resolve against our source files. If this file was
# invoked remotely via HTTP, that means the files are not present locally.
# In that case, use `git clone` to download them to a local temporary dir.
def add_template_repository_to_source_path
  if __FILE__ =~ %r{\Ahttps?://}
    require "tmpdir"
    source_paths.unshift(tempdir = Dir.mktmpdir("jumpy-"))
    at_exit { FileUtils.remove_entry(tempdir) }
    git clone: [
      "--quiet",
      "https://github.com/aadeshere1/jumpy.git",
      tempdir
    ].map(&:shellescape).join(" ")

    if (branch = __FILE__[%r{jumpy/(.+)/template.rb}, 1])
      Dir.chdir(tempdir) { git checkout: branch }
    end
  else
    source_paths.unshift(File.dirname(__FILE__))
  end
end

def rails_version
  @rails_version ||= Gem::Version.new(Rails::VERSION::STRING)
end

def rails_7_or_newer?
  Gem::Requirement.new(">= 7.0.4").satisfied_by? rails_version
end

def add_gems
    add_gem 'devise', '~> 4.9'
    add_gem 'delayed_job_active_record', '~> 4.1', '>= 4.1.7'
    add_gem 'friendly_id', '~> 5.5'
    add_gem 'name_of_person', '~> 1.1'
    add_gem 'simple_form', '~> 5.1'
    add_gem 'sitemap_generator', '~> 6.3'
    add_gem 'rollbar', '~> 3.3'
    
    add_gem 'whenever', require: false

    add_gem "dotenv-rails", "~> 2.7", groups: [:development, :test]
    add_gem "rspec-rails", '~> 6.0', '>= 6.0.1'
    add_gem "factory_bot_rails", '~> 6.2'
    add_gem "ffaker", '~> 2.21'
    add_gem "rubycritic", '~> 4.7', group: [:development]
    add_gem "rubocop", '~> 1.48', '>= 1.48.1', group: [:development]
    add_gem "rubocop-rails", '~> 2.18', group: [:development]
    add_gem "rubocop-performance", '~> 1.16', group: [:development]
    add_gem "rubocop-rspec", '~> 2.19', group: [:development]
    add_gem "annotate", '~> 3.2', group: [:development]
    add_gem "erb_lint", '~> 0.3.1', group: [:development]
    add_gem "letter_opener", '~> 1.8', '>= 1.8.1', group: [:development]
    add_gem "bullet", '~> 7.0', '>= 7.0.7', group: [:development]
    
    add_gem 'shoulda-matchers', '~> 5.1', group: [:test]
    add_gem 'database_cleaner', '~> 2.0', group: [:test]
    add_gem 'rails-controller-testing', '~> 1.0', '>= 1.0.5', group: [:test]
    add_gem 'vcr', '~> 6.1', group: [:test]
    add_gem 'webmock', '~> 3.18', group: [:test]
    add_gem 'simplecov', '~> 0.21.2', require: false, group: [:test]
  
end

def set_application_name
  environment "config.application_name = Rails.application.class.module_parent_name"

  say "You can change application name in file ./config/application.rb"
end

def add_users
  route "root to: 'home#index'"
  generate "devise:install"

  environment "config.action_mailer.default_url_options = { host: 'localhost', port: 3000 }", env: 'development'
  generate :devise, "User", "first_name", "last_name", "email", "phone" "admin:boolean"

  # Set admin default to false
  in_root do
    migration = Dir.glob("db/migrate/*").max_by{ |f| File.mtime(f) }
    gsub_file migration, /:admin/, ":admin, default: false"
  end

  if Gem::Requirement.new("> 5.2").satisfied_by? rails_version
    gsub_file "config/initializers/devise.rb", /  # config.secret_key = .+/, "  config.secret_key = Rails.application.credentials.secret_key_base"
  end

  # inject_into_file("app/models/user.rb", "omniauthable, :", after: "devise :")
end

def copy_templates
  remove_file "app/assets/stylesheets/application.css"


  # directory "app", force: true

  copy_file "app/models/concerns/uid.rb"

  directory "app", force: true
  inject_into_file("app/models/user.rb", "include Uid\n", before: "devise :database_authenticatable")
  

  route "get '/terms', to: 'home#terms'"
  route "get '/privacy', to: 'home#privacy'"

  copy_file ".rubocop.yml"
  copy_file "spec/support/database_cleaner.rb"
  copy_file "spec/support/devise.rb"
  copy_file "spec/support/shoulda_matcher.rb"
  copy_file "spec/support/vcr_setup.rb"
  copy_file "spec/spec_helper.rb", force: true
  copy_file ".erb-lint.yml"
end

def add_delayed_job
  generate "delayed_job:active_record"
  environment "config.active_job.queue_adapter = :delayed_job"  
end

def add_whenever
  run "wheneverize ."
end

def add_friendly_id
  generate "friendly_id"
  # insert_into_file(Dir["db/migrate/**/*friendly_id_slugs.rb"].first, "[5.2]", after: "ActiveRecord::Migration")
  puts "*"*50
  inject_into_file("app/models/user.rb","extend FriendlyId\nfriendly_id :first_name, use: :slugged\n", after: "include Uid\n" )
  puts "*"*50
end

def add_name_of_person
  inject_into_file("app/models/user.rb", "has_person_name\n", after: "friendly_id :first_name, use: :slugged\n")
end

def add_simple_form
  say << "Installing simple form to app"
  generate "simple_form:install"
end

def add_sitemap
  say << "Installing Sitemap and generating sitemap. Edit config/sitemap.rb to add more to sitemap"
  run 'bundle exec rails sitemap:install'
  run 'bundle exec rails sitemap:create'
end

def add_rollbar
  generate "rollbar"
  say "add ROLLBAR_ACCESS_TOKEN variable in your dotfile"
end

def add_rspec
  generate "rspec:install"
  generate "rspec:model user"
end

def add_letter_opener
  environment "config.action_mailer.delivery_method = :letter_opener", env: 'development'
  environment "config.action_mailer.perform_deliveries = true", env: 'development'
end

def add_bullet
  configs = """
  config.after_initialize do
    Bullet.enable        = true
    Bullet.bullet_logger = true
    Bullet.console       = true
    Bullet.rails_logger  = true
    Bullet.add_footer    = true
  end
  """
  inject_into_file("config/environments/development.rb", configs, after: "Rails.application.configure do\n")
end

def setup_staging
  inject_into_file 'app/controllers/application_controller.rb', after: %r{class ApplicationController < ActionController\n} do
    <<-RUBY
    prepend_before_action :http_basic_authenticate
    def http_basic_authenticate
      return unless Rails.env.staging?
      authenticate_or_request_with_http_basic Rails.env do |name, password|
        name == "#{original_app_name}" && password == 'password'
      end
    end
    RUBY
  end
end

def add_gem(name, *options)
  gem(name, *options) unless gem_exists?(name)
end

def gem_exists?(name)
  IO.read("Gemfile") =~ /^\s*gem ['"]#{name}['"]/
end

unless rails_7_or_newer?
  puts "Please update Rails to 7.0.4 or newer to create a application through jumpy"
end

add_template_repository_to_source_path
add_gems
add_simple_form
after_bundle do
  set_application_name
  
  add_users
  
  add_delayed_job
  add_whenever
  
  
  add_sitemap

  rails_command "active_storage:install"
  run "bundle lock --add-platform x86_64-linux"
  add_rspec
  copy_templates
  add_friendly_id
  add_rollbar
  add_letter_opener
  add_bullet

  setup_staging
  
  

  unless ENV["SKIP_GIT"]
    git :init
    git add: "."
    begin
      git commit: %( -m 'Initial commit')
    rescue StandardError => e
      puts e.message
    end
  end

  run "bundle exec rubocop -a"
  run "bundle exec rubocop -A"
  
  say
  say "jumpy app successfully created!", :blue
  say
  say "To get started with your new app:", :green
  say "  cd #{original_app_name}"
  say
  say "  # Update config/database.yml with your database credentials"
  say
  say "  rails db:create"
  say "  rails g noticed:model"
  say "  rails db:migrate"
  say "  rails g madmin:install # Generate admin dashboards"
  say "  gem install foreman"
  say "  bin/dev"
end