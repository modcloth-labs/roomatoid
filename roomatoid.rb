require 'sinatra/base'
require 'rubygems'
require 'google/api_client'
require 'google/api_client/client_secrets'

class Roomatoid < Sinatra::Base

  def calendar; settings.calendar; end
  def client; settings.client; end
  def client_secrets; settings.client_secrets; end

  configure do
    client = Google::APIClient.new(
      application_name: "Roomatoid",
      application_version: "0.1.0"
    )

    client_secrets = Google::APIClient::ClientSecrets.load
    client.authorization = client_secrets.to_authorization
    client.authorization.scope = 'https://www.googleapis.com/auth/calendar'
    client.authorization.redirect_uri = 'http://localhost:9292/oauth2callback'
    calendar = client.discovered_api('calendar', 'v3')
    set :calendar, calendar
    set :client, client
    set :client_secrets, client_secrets
  end

  before do
    unless client.authorization.access_token || request.path_info =~ /\A\/oauth2/
      redirect to '/oauth2authorize'
    end
  end

  get '/oauth2authorize' do
    redirect client.authorization.authorization_uri.to_s, 303
  end

  get '/oauth2callback' do
    client.authorization.code = params[:code] if params[:code]
    client.authorization.fetch_access_token!
    redirect to '/'
  end

  get "/" do
    results = client.execute(:api_method => calendar.events.list,
                              :parameters => {'calendarId' => 'primary'},
                              :authorization => client.authorization.dup)
    puts results.class
    puts results.methods.sort.inspect
    puts results.data.class
    puts results.data.methods.sort.inspect
    @data = results.data.to_json
    erb :index
  end
end
