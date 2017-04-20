# CloudBurrito
# Jackson Argo 2017

require_relative 'models/patron'
require_relative 'models/package'
require_relative 'controllers/slack_controller'
require_relative 'lib/messenger'
require_relative 'lib/requestlogger'
require_relative 'lib/events'
require 'sinatra/base'

class CloudBurrito < Sinatra::Base

  Mongoid.load!("config/mongoid.yml")

  ##
  ## Functions
  ##

  def valid_token?(token)
    token == settings.slack_veri_token
  end

  ## 
  ## Load secrets
  ##

  secrets = {}
  if File.exist? "config/secrets.yml"
    secrets = YAML.load_file "config/secrets.yml"
    secrets = secrets[settings.environment.to_s]
  end
  slack_veri_token = secrets["slack_veri_token"]
  slack_auth_token = secrets["slack_auth_token"]
  slack_veri_token ||= "XXX_burrito_XXX"
  slack_auth_token ||= "xoxb-???"
  set :slack_veri_token, slack_veri_token
  set :slack_auth_token, slack_auth_token

  ##
  ## Serve burritos
  ##

  puts "Environment: #{settings.environment}"
  puts "Seed: #{Random::DEFAULT.seed}"

  # Start events manager
#  events = Events.new
#  events.start

  not_found do
    if request.path == '/slack' and request.request_method == 'POST'
      "404: Burrito Not Found!"
    elsif request.accept? "text/html"
      @content = erb :error404
      return erb :beautify
    else
      "404: Burrito Not Found!"
    end
  end

  error 401 do
    # Return text for post in /slack
    if request.path == '/slack' and request.request_method == 'POST'
      "401: Burrito Unauthorized!"
    elsif request.accept? "text/html"
      @content = erb :error401
      erb :beautify
    else
      "401: Burrito Unauthorized!"
    end
  end

  error 500 do
    "500: A nasty burrito was found!"
  end

  before '/slack' do
    halt 401 unless valid_token? params["token"]
    halt 401 unless params["user_id"]
  end

  get '/' do
    if request.accept? "text/html"
      @content = erb :index
      erb :beautify
    else
      "Welcome to Cloud Burrito!"
    end
  end

  get '/stats' do
    @stats = { 
      "patrons" => { 
        "total" => Patron.count,
        "active" => Patron.where(is_active: true).count
      },
      "served" => { 
        "burritos" => Package.where(received: true).count,
        "calories" => Package.where(received: true).count * 350
      }
    }

    if request.accept? "text/html"
      @content = erb :stats
      erb :beautify
    elsif request.accept? "application/json"
      return JSON.dump({ 'ok' => true, 'stats' => @stats })
    end
  end

  get '/rules' do
    @content = erb :rules
    erb :beautify
  end

  get '/cbtp' do
    @content = "This page is coming soon!"
    erb :beautify
  end

  get '/user' do
    user_id = params["user_id"]
    # Require a user id
    halt 401 unless params["user_id"]
    # Require that the user exists
    begin
      @patron = Patron.find(user_id)
    rescue
      halt 401
    end
    # Require a matching token
    halt 401 unless @patron.user_token
    halt 401 unless @patron.user_token == params["token"]
    # Log this request
    RequestLogger.new(uri: '/user', method: :get, params: params, patron: @patron).save
    # Render the user stats
    @content = erb :user
    erb :beautify
  end

  post '/slack' do
    # Check if the user exists
    unless Patron.where(user_id: params["user_id"]).exists?
      Patron.new(user_id: params["user_id"]).save
      return erb :slack_new_user
    end

    # Create the controller
    controller = SlackController.new params
    # Log this request
    my_logger = RequestLogger.new(
      uri: '/slack',
      method: :post,
      params: params,
      patron: controller.patron
    )
    # Do the needful
    cmd = params["text"]
    cmd = cmd.strip unless cmd.nil?
    if controller.actions.include? cmd
      my_logger.controller_action = cmd
      my_logger.response = controller.send(cmd)
    else
      my_logger.controller_action = :help
      my_logger.response = erb :slack_help
    end
    my_logger.save
    my_logger.response
  end
end
