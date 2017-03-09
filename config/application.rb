require File.expand_path('../boot', __FILE__)
require 'rails/all'

Bundler.require(*Rails.groups)

APP_NAME = 'login.gov'.freeze
CONTACT_PHONE_NUMBER = '1-844-USA-GOV1 (1-844-872-4681)'.freeze

module Upaya
  class Application < Rails::Application
    config.active_job.queue_adapter = :sidekiq
    config.active_record.raise_in_transactional_callbacks = true
    config.autoload_paths << Rails.root.join('app/mailers/concerns')
    config.time_zone = 'UTC'
    config.middleware.use Rack::Attack
    config.browserify_rails.force = true
    config.browserify_rails.commandline_options = '-t [ babelify --presets [ es2015 ] ]'
    config.i18n.load_path += Dir[Rails.root.join('config', 'locales', '**', '*.{yml}')]

    routes.default_url_options[:host] = Figaro.env.domain_name

    if Rails.env.test?
      config.browserify_rails.commandline_options += ' -p [ proxyquireify/plugin ]'
      # Make sure Browserify is triggered when asked to serve javascript spec files
      config.browserify_rails.paths << lambda do |path|
        path.start_with?(Rails.root.join('spec/javascripts').to_s)
      end
    end

    config.middleware.insert_before 0, 'Rack::Cors' do
      allow do
        origins '*'
        resource '/.well-known/openid-configuration', headers: :any, methods: [:get]
        resource '/api/openid_connect/certs', headers: :any, methods: [:get]
        resource '/api/openid_connect/token',
                 credentials: true,
                 headers: :any,
                 methods: [:post, :options]
        resource '/api/openid_connect/userinfo', headers: :any, methods: [:get]
      end
    end
  end
end
