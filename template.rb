require "fileutils"
require "shellwords"
require "pry"
require "open3"

@model_name = ""

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
    add_gem 'delayed_job_active_record', '~> 4.1', '>= 4.1.8'
    add_gem 'friendly_id', '~> 5.5', '>= 5.5.1'
    add_gem 'simple_form', '~> 5.3'
    add_gem 'sitemap_generator', '~> 6.3'
    add_gem 'sassc-rails', '~> 2.1', '>= 2.1.2'
    add_gem 'rollbar', '~> 3.5', '>= 3.5.1'
    add_gem 'rspec-rails', '~> 6.1', '>= 6.1.1', group: [:development, :test]
    add_gem 'factory_bot_rails', '~> 6.4', '>= 6.4.3', group: [:development, :test]
    add_gem 'ffaker', '~> 2.23', group: [:development, :test]
    add_gem 'shoulda-matchers', '~> 6.1', group: [:development, :test]
    add_gem 'simplecov', '~> 0.22.0', require: false, group: [:development, :test]
    add_gem 'database_cleaner', '~> 2.0', '>= 2.0.2', group: [:development, :test]
    add_gem 'dotenv-rails', '~> 3.0', '>= 3.0.2', groups: [:development, :test]
    add_gem 'rails-controller-testing', '~> 1.0', '>= 1.0.5', group: [:development, :test]
    add_gem 'vcr', '~> 6.2', group: [:development, :test]
    add_gem 'webmock', '~> 3.20', group: [:development, :test]
    add_gem 'rubycritic', '~> 4.9', group: [:development]
    add_gem 'rubocop-rails', '~> 2.23', '>= 2.23.1', group: [:development]
    add_gem 'rubocop-performance', '~> 1.20', '>= 1.20.2', group: [:development]
    add_gem 'rubocop-rspec', '~> 2.26', '>= 2.26.1', group: [:development]
    add_gem 'rubocop-factory_bot', '~> 2.25', '>= 2.25.1', group: [:development]
    add_gem 'annotate', '~> 3.2', group: [:development]
    add_gem 'erb_lint', '~> 0.5.0', group: [:development]
    add_gem 'letter_opener', '~> 1.9', group: [:development]
    add_gem 'bullet', '~> 7.1', '>= 7.1.6', group: [:development]
    add_gem 'rails_live_reload', '~> 0.3.5', group: [:development]
    add_gem 'paper_trail', '~> 15.1'
    gem 'i18n-js', '~> 4.2', '>= 4.2.3'
end

def add_yarn_packages
  run "yarn add yup"
end

def add_yup_validation
  create_file 'app/javascript/validation.js', <<~JS
  import { object, string } from 'yup';

  document.addEventListener('DOMContentLoaded', () => {
    // Select all forms on the page
    const forms = document.querySelectorAll('form');

    forms.forEach(form => {
      // Check if the form is a sign-up form
      if (form.id === 'new_user') {
        // Define the Yup schema for form validation
        const userSchema = object({
          email: string().email('Invalid email').required('Email is required'),
          password: string().min(8, 'Password must be at least 8 characters').required('Password is required')
        });

        form.addEventListener('submit', async (event) => {
          event.preventDefault(); // Prevent default form submission

          const formData = new FormData(form);

          try {
            // Extract email and password from form data
            const email = formData.get('user[email]');
            const password = formData.get('user[password]');

            // Validate email and password using Yup schema
            const validatedData = await userSchema.validate({ email, password });

            // Form data is valid, continue with form submission
            form.submit();
          } catch (error) {
            // Handle validation errors
            console.error('Validation Error:', error);
            // Display validation errors to the user
          }
        });
      }
    });
  });
  JS
end

def add_yup_integration
  append_to_file 'app/javascript/application.js', "import './validation.js';\n"
end

def set_application_name
  environment "config.application_name = Rails.application.class.module_parent_name"

  say "You can change application name in file ./config/application.rb"
end

def add_users
  if yes?("Would you like to install Devise for user management ?")
    add_gem 'devise', '~> 4.9', '>= 4.9.3'
    run "bundle install"
    generate "devise:install"
    @model_name = ask("What would you like the user model to be called? [user]")
    say "Fields first_name, last_name, first_name_kana, last_name_kana,phone, postalcode, prefecture, city, street_address would be created. If unneccessary please remove from migration file."
    @model_name = "user" if @model_name.blank?
    route "root to: 'home#index'"
    environment "config.action_mailer.default_url_options = { host: 'localhost', port: 3000 }", env: 'development'
    generate :devise, @model_name, "first_name", "last_name", "first_name_kana", "last_name_kana","phone", "postalcode", "prefecture", "city", "street_address"

    # # Set admin default to false
    # in_root do
    #   migration = Dir.glob("db/migrate/*").max_by{ |f| File.mtime(f) }
    #   gsub_file migration, /:admin/, ":admin, default: false"
    # end

    # if Gem::Requirement.new("> 5.2").satisfied_by? rails_version
    #   gsub_file "config/initializers/devise.rb", /  # config.secret_key = .+/, "  config.secret_key = Rails.application.credentials.secret_key_base"
    # end

    rails_command "g migration AddUidTo#{@model_name.capitalize}s uid:string:uniq"
    rails_command "g migration AddSlugTo#{@model_name.capitalize}s slug:uniq"
    gsub_file(Dir["db/migrate/**/*uid_to_#{@model_name.downcase}s.rb"].first, /:uid, :string/, ":uid, :string,after: :id")


    
    inject_into_file("app/models/#{@model_name.downcase}.rb", "  include Uid\n  has_paper_trail\n", before: "devise :database_authenticatable\n")

    if yes?("Would you like to add active admin for admin features ? ")
      gem 'activeadmin', '~> 3.2', '>= 3.2.1'

      run "bundle install"
      generate "active_admin:install"
      run "bundle exec rails db:create"
      run "bundle exec rails db:migrate"
      generate "active_admin:resource", @model_name
    end
    run "bundle exec rails db:create db:migrate"
  end
end

def copy_templates
  remove_file "app/assets/stylesheets/application.css"
  # directory "app", force: true
  copy_file "app/validators/password_validator.rb"
  inject_into_file("app/models/#{@model_name.downcase}.rb", "validates :password, password: true, if: proc { password.present? && User.password_length.include?(password.length) }\n", after: ":validatable\n")
  directory "app", force: true
  copy_file ".rubocop.yml"
  copy_file ".erb-lint.yml"
  copy_file ".github/PULL_REQUEST_TEMPLATE/release.md"
  copy_file ".github/workflows/lint_and_tests.yml"
  copy_file ".github/ISSUE_TEMPLATE.md"
  copy_file ".github/PULL_REQUEST_TEMPLATE.md"
  copy_file "lib/tasks/annotate.rake"
  copy_file "lib/tasks/lint.rake"
  copy_file "lib/templates/active_record/migration/create_table_migration.rb.tt"
end

def error_pages
  generate "controller errors not_found internal_server_error unprocessable_entity"
  route "match '/404', to: 'errors#not_found', via: :all"
  route "match '/500', to: 'errors#internal_server_error', via: :all"
  route "match '/422', to: 'errors#unprocessable_entity', via: :all"
  environment "config.exceptions_app = routes"
end

def add_delayed_job
  generate "delayed_job:active_record"
  environment "config.active_job.queue_adapter = :delayed_job"
end

def add_friendly_id
  generate "friendly_id"
  # insert_into_file(Dir["db/migrate/**/*friendly_id_slugs.rb"].first, "[5.2]", after: "ActiveRecord::Migration")
  puts "*"*50
  inject_into_file("app/models/#{@model_name.downcase}.rb","extend FriendlyId\nfriendly_id :first_name, use: :slugged\n", after: "include Uid\n" )
  puts "*"*50
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
  run "bundle exec rails db:migrate"
  generate "rspec:install"
  # generate "rspec:model #{model}"

  files = Dir['app/models/*rb']
  models = files.map{ |m| File.basename(m, '.rb').camelize}
  models = models.reject {|e| e == "ApplicationRecord"}
  models.each {|m| generate "rspec:model #{m}"}
  gsub_file("spec/rails_helper.rb", "# Dir[Rails.root.join('spec', 'support'", "Dir[Rails.root.join('spec', 'support'")
  gsub_file("spec/rails_helper.rb", "require 'spec_helper'", "")
  gsub_file("spec/rails_helper.rb", "ActiveRecord::Migration.maintain_test_schema!", "ActiveRecord::Migration.maintain_test_schema! if Rails.env.test?")
  # copy spec helper here
  copy_file "spec/support/database_cleaner.rb"
  copy_file "spec/support/devise.rb"
  copy_file "spec/support/shoulda_matcher.rb"
  copy_file "spec/support/vcr_setup.rb"
  copy_file "spec/support/factory_bot.rb"
  copy_file "spec/spec_helper.rb", force: true

end

def add_letter_opener
  environment "config.action_mailer.delivery_method = :letter_opener", env: 'development'
  environment "config.action_mailer.perform_deliveries = true", env: 'development'
end

def add_bullet_and_active_storage_options
  configs = """
  config.after_initialize do
    Bullet.enable        = true
    Bullet.bullet_logger = true
    Bullet.console       = true
    Bullet.rails_logger  = true
    Bullet.add_footer    = true

    ActiveStorage::Current.url_options = {host: 'http://localhost:3000'}
  end
  """
  inject_into_file("config/environments/development.rb", configs, after: "Rails.application.configure do\n")
end

def setup_staging
  inject_into_file 'app/controllers/application_controller.rb', after: %r{class ApplicationController < ActionController::Base\n} do
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

def add_node_version
  command = "curl -L https://github.com/nodejs/node/releases\?q\=lts\&expanded\=true"
  Open3.popen3(command) do |stdin, stdout, stderr, wait_thr|
    version = stdout.read.scan(/Version [0-9]+\.[0-9]+\.[0-9]+/).first
    version_number = version.match(/[0-9]+\.[0-9]+\.[0-9]+/)[0] if version
    File.write('.node-version', version_number) if version_number
  end
end

def add_smtp_setting
  action_mailer = """ActionMailer::Base.smtp_settings = {
    user_name: ENV['SMTP_USER_NAME'] || 'apikey', # This is the string literal 'apikey', NOT the ID of your API key
    password: ENV['SMTP_PASSWORD'],
    # This is the secret sendgrid API key which was issued during API key creation
    domain: 'yourdomain.com', #TODO Change the domain to your website
    address: 'smtp.sendgrid.net',
    port: 587,
    authentication: :plain,
    enable_starttls_auto: true
  }\n"""
  append_file "config/environment.rb", action_mailer
end

def add_gem(name, *options)
  gem(name, *options) unless gem_exists?(name)
end

def gem_exists?(name)
  IO.read("Gemfile") =~ /^\s*gem ['"]#{name}['"]/
end

unless rails_7_or_newer?
  puts "Please update Rails to 7.0.5 or newer to create a application through jumpy"
end


add_template_repository_to_source_path
add_node_version
add_gems

def add_i18n_js_config
  create_file 'config/i18n.yml', <<-YAML
  translations:
    - file: "app/javascript/locales.json"
      patterns:
        - "errors.*"
        - "activerecord.errors.*"
        - "*.hello.*"
  YAML
end

def setup_i18n_js
    create_file 'app/javascript/locales.json', <<-JSON
      {
   
      }
    JSON

  append_to_file 'app/javascript/application.js', <<-JS
      import I18n from 'i18n-js';
      import translations from './locales.json';

      I18n.translations = translations;
    JS
end

def export_i18n_translations
  run "bundle exec i18n export"
end

after_bundle do

  add_yarn_packages
  add_yup_validation
  add_yup_integration
  run "bin/rails javascript:install:webpack"

  set_application_name

  copy_file "app/models/concerns/uid.rb"

  add_users
  add_i18n_js_config
  setup_i18n_js
  export_i18n_translations
  add_rspec
  add_friendly_id
  add_delayed_job
  add_sitemap
  add_simple_form
  rails_command "active_storage:install"
  run "bundle lock --add-platform x86_64-linux"
  # gsub_file "config/initializers/devise.rb", /  # config.secret_key = .+/, "  config.secret_key = Rails.application.credentials.secret_key_base"

  copy_templates

  add_rollbar
  add_letter_opener
  add_bullet_and_active_storage_options
  setup_staging
  add_node_version
  add_smtp_setting
  run "bundle exec rails db:migrate"
  generate "controller home index"
  error_pages

  def add_arctic_admin
  #   # Add Arctic Admin gem to Gemfile
    add_gem 'arctic_admin', '~> 4.3', '>= 4.3.1'
  
  #   # Bundle install
    run "bundle install"
  
  #   # Configuration for Arctic Admin
    inject_into_file "config/initializers/active_admin.rb", before: "# == Register Stylesheets\n" do
      <<-RUBY
      meta_tags_options = { viewport: 'width=device-width, initial-scale=1' }
      config.meta_tags = meta_tags_options
      config.meta_tags_for_logged_out_pages = meta_tags_options\n\n
      RUBY
    end
  
  #   # Installation of Font Awesome
    run "yarn add @fortawesome/fontawesome-free"
  
  #   # # Use Arctic Admin CSS with Sprockets
  #   # inject_into_file "app/assets/stylesheets/active_admin.css", before: " *= require active_admin/base\n" do
  #   #   " *= require arctic_admin/base\n"
  #   # end
  
  #   # Remove the line that requires active_admin/base in active_admin.css
  #   # gsub_file "app/assets/stylesheets/active_admin.css", " *= require active_admin/base\n", ""


  # # Add SCSS support
    create_file "app/assets/stylesheets/active_admin.scss", <<-SCSS
    @import "arctic_admin/base";
    SCSS

  #   # Remove the line that imports active_admin/base in active_admin.scss
  gsub_file "app/assets/stylesheets/active_admin.scss", '@import "active_admin/base";', ''
  end
  
  # # Call the method to add Arctic Admin
  add_arctic_admin

  generate 'paper_trail:install'
  rails_command 'db:migrate'

  generate "model Contact email:string content:text"

  create_file "app/controllers/contacts_controller.rb", <<-CODE
    class ContactsController < ApplicationController
      def new
        @contact = Contact.new
      end

      def create
        @contact = Contact.new(contact_params)
        if @contact.save
          redirect_to new_contact_path, notice: "Message sent successfully"
        else
          render :new
        end
      end

      private

      def contact_params
        params.require(:contact).permit(:email, :content)
      end
    end
  CODE
  create_file "app/controllers/static_pages_controller.rb", <<-CODE
    class StaticPagesController < ApplicationController
      def privacy_policy
      end
      def terms
      end
    end
  CODE

  route <<-CODE
    resources :contacts, only: [:new, :create]
    get 'terms', to: 'static_pages#terms'
    get 'privacy_policy', to: 'static_pages#privacy_policy'
  CODE

  create_file "app/views/contacts/new.html.erb", <<-CODE
  <section class="bg-white dark:bg-white-500 min-h-screen">
    <div class="py-8 lg:py-16 px-4 mx-auto max-w-screen-md">
        <h2 class="mb-4 text-4xl tracking-tight font-extrabold text-center text-gray-900 dark:text-black">Contact Us</h2>

        <%= form_with(model: @contact, local: true) do |form| %>
          <div class="space-y-8">
            <div>
              <%= form.label :email, class: "block mb-2 text-sm font-medium text-gray-900 dark:text-black-300" %>
              <%= form.text_field :email, class: "shadow-sm bg-gray-50 border border-gray-300 text-black-900 text-sm rounded-lg focus:ring-primary-500 focus:border-primary-500 block w-full p-2.5 dark:bg-white-700 dark:border-gray-600 dark:placeholder-gray-400 dark:text-black dark:focus:ring-primary-500 dark:focus:border-primary-500 dark:shadow-sm-light", placeholder: "name@example.com", required: true %>
            </div>

            <div class="sm:col-span-2">
              <%= form.label :content, class: "block mb-2 text-sm font-medium text-black-900 dark:text-black-400" %>
              <%= form.text_area :content, rows: "6", class: "block p-2.5 w-full text-sm text-gray-900 bg-white-50 rounded-lg shadow-sm border border-gray-300 focus:ring-primary-500 focus:border-primary-500 dark:bg-white-700 dark:border-gray-600 dark:placeholder-gray-400 dark:text-black dark:focus:ring-primary-500 dark:focus:border-primary-500", placeholder: "Leave a comment..." %>
            </div>

            <div class="flex justify-center">
              <%= form.submit "Send message", class: "py-3 px-5 text-sm font-medium text-center text-white rounded-lg bg-blue-700 sm:w-fit hover:bg-primary-800 focus:ring-4 focus:outline-none focus:ring-primary-300 dark:bg-primary-600 dark:hover:bg-primary-700 dark:focus:ring-primary-800" %>
            </div>
          </div>
        <% end %>
      </div>
  </section>

  CODE

  create_file "app/views/static_pages/terms.html.erb", <<-CODE
    <div class="min-h-screen flex items-center justify-center bg-white px-20 container mx-auto ">
      <div class="container mx-auto px-20 py-5 bg-gray-50 rounded shadow-lg">
        <h1 class="text-3xl font-bold mb-4 text-center">Terms and Condition</h1>

        <p class="mb-4">
          This privacy policy sets out how our website uses and protects any information that you give us when you use
          There are many variations of passages of Lorem Ipsum available, but the majority have suffered alteration in some form, by injected humour, or randomised words which don't look even slightly believable. If you are going to use a passage of Lorem Ipsum, you need to be sure there isn't anything embarrassing hidden in the middle of text. All the Lorem Ipsum generators on the Internet tend to repeat predefined chunks as necessary, making this the first true generator on the Internet. It uses a dictionary of over 200 Latin words, combined with a handful of model sentence structures, to generate Lorem Ipsum which looks reasonable. The generated Lorem Ipsum is therefore always free from repetition, injected humour, or non-characteristic words etc.
        </p>

        <p class="mb-4">
          We are committed to ensuring that your information is secure. In order to prevent unauthorized access or
          disclosure,
          we have put in place suitable physical, electronic, and managerial procedures to safeguard and secure the
          information we collect online.
        </p>

        <p class="mb-4">
          A cookie is a small file that asks permission to be placed on your computer's hard drive. Once you agree,There are many variations of passages of Lorem Ipsum available, but the majority have suffered alteration in some form, by injected humour, or randomised words which don't look even slightly believable. If you are going to use a passage of Lorem Ipsum, you need to be sure there isn't anything embarrassing hidden in the middle of text. All the Lorem Ipsum generators on the Internet tend to repeat predefined chunks as necessary, making this the first true generator on the Internet. It uses a dictionary of over 200 Latin words, combined with a handful of model sentence structures, to generate Lorem Ipsum which looks reasonable. The generated Lorem Ipsum is therefore always free from repetition, injected humour, or non-characteristic words etc.
        </p>

        <p class="mb-4">
          Overall, cookies help us provide you with a better website by enabling us to monitor which pages you find There are many variations of passages of Lorem Ipsum available, but the majority have suffered alteration in some form, by injected humour, or randomised words which don't look even slightly believable. If you are going to use a passage of Lorem Ipsum, you need to be sure there isn't anything embarrassing hidden in the middle of text. All the Lorem Ipsum generators on the Internet tend to repeat predefined chunks as necessary, making this the first true generator on the Internet. It uses a dictionary of over 200 Latin words, combined with a handful of model sentence structures, to generate Lorem Ipsum which looks reasonable. The generated Lorem Ipsum is therefore always free from repetition, injected humour, or non-characteristic words etc.
        </p>
        <p class="mb-4">
          This privacy policy is subject to change without notice.There are many variations of passages of Lorem Ipsum available, but the majority have suffered alteration in some form, by injected humour, or randomised words which don't look even slightly believable. If you are going to use a passage of Lorem Ipsum, you need to be sure there isn't anything embarrassing hidden in the middle of text. All the Lorem Ipsum generators on the Internet tend to repeat predefined chunks as necessary, making this the first true generator on the Internet. It uses a dictionary of over 200 Latin words, combined with a handful of model sentence structures, to generate Lorem Ipsum which looks reasonable. The generated Lorem Ipsum is therefore always free from repetition, injected humour, or non-characteristic words etc.
        </p>
      </div>
  </div>


  CODE

  create_file "app/views/static_pages/privacy_policy.html.erb", <<-CODE
  <div class="min-h-screen flex items-center justify-center bg-white px-20 container mx-auto ">
      <div class="container mx-auto px-20 py-5 bg-gray-50 rounded shadow-lg">
        <h1 class="text-3xl font-bold mb-4 text-center">Privacy and Policy</h1>

        <p class="mb-4">
          This privacy policy sets out how our website uses and protects any information that you give us when you use
          There are many variations of passages of Lorem Ipsum available, but the majority have suffered alteration in some form, by injected humour, or randomised words which don't look even slightly believable. If you are going to use a passage of Lorem Ipsum, you need to be sure there isn't anything embarrassing hidden in the middle of text. All the Lorem Ipsum generators on the Internet tend to repeat predefined chunks as necessary, making this the first true generator on the Internet. It uses a dictionary of over 200 Latin words, combined with a handful of model sentence structures, to generate Lorem Ipsum which looks reasonable. The generated Lorem Ipsum is therefore always free from repetition, injected humour, or non-characteristic words etc.
        </p>

        <p class="mb-4">
          We are committed to ensuring that your information is secure. In order to prevent unauthorized access or
          disclosure,
          we have put in place suitable physical, electronic, and managerial procedures to safeguard and secure the
          information we collect online.
        </p>

        <p class="mb-4">
          A cookie is a small file that asks permission to be placed on your computer's hard drive. Once you agree,There are many variations of passages of Lorem Ipsum available, but the majority have suffered alteration in some form, by injected humour, or randomised words which don't look even slightly believable. If you are going to use a passage of Lorem Ipsum, you need to be sure there isn't anything embarrassing hidden in the middle of text. All the Lorem Ipsum generators on the Internet tend to repeat predefined chunks as necessary, making this the first true generator on the Internet. It uses a dictionary of over 200 Latin words, combined with a handful of model sentence structures, to generate Lorem Ipsum which looks reasonable. The generated Lorem Ipsum is therefore always free from repetition, injected humour, or non-characteristic words etc.
        </p>

        <p class="mb-4">
          Overall, cookies help us provide you with a better website by enabling us to monitor which pages you find There are many variations of passages of Lorem Ipsum available, but the majority have suffered alteration in some form, by injected humour, or randomised words which don't look even slightly believable. If you are going to use a passage of Lorem Ipsum, you need to be sure there isn't anything embarrassing hidden in the middle of text. All the Lorem Ipsum generators on the Internet tend to repeat predefined chunks as necessary, making this the first true generator on the Internet. It uses a dictionary of over 200 Latin words, combined with a handful of model sentence structures, to generate Lorem Ipsum which looks reasonable. The generated Lorem Ipsum is therefore always free from repetition, injected humour, or non-characteristic words etc.
        </p>
        <p class="mb-4">
          This privacy policy is subject to change without notice.There are many variations of passages of Lorem Ipsum available, but the majority have suffered alteration in some form, by injected humour, or randomised words which don't look even slightly believable. If you are going to use a passage of Lorem Ipsum, you need to be sure there isn't anything embarrassing hidden in the middle of text. All the Lorem Ipsum generators on the Internet tend to repeat predefined chunks as necessary, making this the first true generator on the Internet. It uses a dictionary of over 200 Latin words, combined with a handful of model sentence structures, to generate Lorem Ipsum which looks reasonable. The generated Lorem Ipsum is therefore always free from repetition, injected humour, or non-characteristic words etc.
        </p>
      </div>
  </div>

  CODE

  create_file "app/admin/contacts.rb", <<-CODE
    ActiveAdmin.register Contact do
      permit_params :email, :content
    end
  CODE

  
  rails_command 'db:migrate'
  
    inject_into_file 'app/models/contact.rb', after: %r{class Contact < ApplicationRecord\n} do
      <<-RUBY
        def self.ransackable_attributes(auth_object = nil)
          ["content", "created_at", "email", "id", "id_value", "uid", "updated_at"]
        end
      RUBY
    end
  

  run "cp config/environments/production.rb config/environments/staging.rb"

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
  say "#{original_app_name} successfully created!", :blue
  say
  say "To get started with your new app:", :green
  say "  cd #{original_app_name}"
  say "  #Update config/database.yml with your database credentials"
  say "  rails db:create"
  say "  rails db:migrate"

  say "  bin/dev"
end


# add node version
# add ruby version


# https://namespace-inc.atlassian.net/wiki/spaces/NI/pages/2267971585/Ruby+on+Rails+-+Validators#Katakana-name
