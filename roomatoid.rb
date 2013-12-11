require 'sinatra/base'
require 'rubygems'
require 'google/api_client'
require 'google/api_client/client_secrets'
require 'google/api_client/auth/file_storage'

class Roomatoid < Sinatra::Base
  CREDENTIAL_STORE_FILE = "#{$0}-oauth2.json"

  def calendar; settings.calendar; end
  def client; settings.client; end

  def user_credentials
    @authorization ||= (
      auth = client.authorization.dup
      auth.redirect_uri = 'http://localhost:9292/oauth2callback'
      auth.update_token!(session)
      auth
    )
  end

  configure do
    client = Google::APIClient.new(
      application_name: "Roomatoid",
      application_version: "0.1.0"
    )

    auth_storage = Google::APIClient::FileStorage.new(CREDENTIAL_STORE_FILE)
    if auth_storage.authorization.nil?
      client_secrets = Google::APIClient::ClientSecrets.load
      client.authorization = client_secrets.to_authorization
      client.authorization.scope = 'https://www.googleapis.com/auth/calendar'
    else
      client.authorization = auth_storage.authorization
    end

    calendar = client.discovered_api('calendar', 'v3')

    set :calendar, calendar
    set :client, client
  end

  before do
    unless user_credentials.access_token || request.path_info =~ /\A\/oauth2/
      redirect to '/oauth2authorize'
    end
  end

  after do
    session[:access_token] = user_credentials.access_token
    session[:refresh_token] = user_credentials.refresh_token
    session[:expires_in] = user_credentials.expires_in
    session[:issued_at] = user_credentials.issued_at

    auth_storage = Google::APIClient::FileStorage.new(CREDENTIAL_STORE_FILE)
    auth_storage.write_credentials(user_credentials)
  end

  get '/oauth2authorize' do
    redirect user_credentials.authorization_uri.to_s, 303
  end

  get '/oauth2callback' do
    user_credentials.code = params[:code] if params[:code]
    user_credentials.fetch_access_token!
    redirect to '/'
  end

  get "/" do
    results = client.execute(:api_method => calendar.calendar_list.list,
                              :authorization => user_credentials)
    @conference_rooms = results.data.items.select { |i| i.summary.include? "Conf" }
    erb :index
  end
end
