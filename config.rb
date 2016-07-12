# require "middleman-core"

class MinifyJsonExtension < ::Middleman::Extension
  def initialize( app, options_hash={}, &block )
    super
    require 'json'
    require 'json/minify'
  end

  def ready
    app.use Rack
  end

  class Rack
    def initialize(app, options={})
      @app = app
    end

    def call(env)
      status, headers, response = @app.call(env)
      if 'application/json' == headers[ 'Content-Type' ]
        minified = JSON.minify ::Middleman::Util.extract_response_text( response )
        headers['Content-Length'] = ::Rack::Utils.bytesize(minified).to_s
        response = [minified]
      end
      return status, headers, response
    end
  end
end

Middleman::Extensions.register( :minify_json ) { MinifyJsonExtension }

page '/*.xml', layout: false
page '/*.json', layout: false
page '/*.txt', layout: false

configure :development do
  activate :livereload
end

configure :build do
  activate :relative_assets
  activate :minify_json
  activate :minify_css
  # activate :minify_javascript
end
