require_relative '../cloudburrito'
require 'rspec'
require 'rack/test'

describe 'The CloudBurrito app' do
  include Rack::Test::Methods

  def app
    CloudBurrito
  end

  before(:each) do
    Package.delete_all
    Patron.delete_all
  end

  def token
    CloudBurrito.slack_veri_token
  end

  context 'GET /' do
    it "returns text/plain" do
      header "Accept", "text/plain"
      get '/'
      expect(last_response).to be_ok
      expect(last_response.body).to eq("Welcome to Cloud Burrito!")
    end

    it "returns text/html" do
      get '/'
      expect(last_response).to be_ok
      expect(last_response.body).not_to eq("Welcome to Cloud Burrito!")
    end
  end

  context 'GET /notaburrito' do
    it "returns 404 with text/plain" do
      header "Accept", "text/plain"
      get '/notaburrito'
      expect(last_response.status).to eq(404)
      expect(last_response.body).to eq("404: Burrito Not Found!")
    end

    it "returns 404 with text/html" do
      get '/notaburrito'
      expect(last_response.status).to eq(404)
      expect(last_response.body).not_to eq("404: Burrito Not Found!")
    end
  end

  context 'GET /stats' do
    it 'returns text/html' do
      get '/stats'
      expect(last_response).to be_ok
    end

    it 'returns application/json' do
      header "Accept", "application/json"
      get '/stats'
      expect(last_response).to be_ok
      x = JSON.parse last_response.body
      expect(x['ok']).to be true
    end
  end

  context 'GET /rules' do
    it 'returns text/html' do
      get '/rules'
      expect(last_response).to be_ok
    end
  end

  context 'GET /cbtp' do
    it 'returns text/html' do
      get '/cbtp'
      expect(last_response).to be_ok
      expect(last_response.body).to match(/coming soon/)
    end
  end

  context 'GET /slack' do
    it "requires user_id" do
      get '/slack'
      expect(last_response.status).to eq(401)
    end

    it "requires token" do
      get '/slack', user_id: 1
      expect(last_response.status).to eq(401)
    end

    it "returns 404" do
      get '/slack', token: token, user_id: 1
      expect(last_response.status).to eq(404)
    end
  end

  context 'POST /slack' do
    it "requires user_id" do
      post '/slack'
      expect(last_response.status).to eq(401)
    end

    it "requires token" do
      post '/slack', user_id: 1
      expect(last_response.status).to eq(401)
      expect(last_response.body).to eq("401: Burrito Unauthorized!")
    end

    context 'new user' do
      it "users automatically added" do
        post '/slack', { token: token, user_id: '1', text: "" }
        expect(Patron.count).to eq(1)
      end
  
      it "gets welcome page" do
        post '/slack', { token: token, user_id: '1', text: "" }
        expect(last_response).to be_ok
        expect(last_response.body).to eq("Welcome to the Cloud Burrito, where all your delicious dreams come true!
Now that you're here, you'll need to know how this works.
To join the Cloud Burrito type:
>/cloudburrito join
Once you are in the Cloud Burrito you will need to wait an hour before you can request a burrito, which you can do by typing in the following:
>/cloudburrito feed
A random person in the Cloud Burrito pool party will be selected to bring you a burrito, once you have received the burrito, you must acknowledge by typing in the following:
>/cloudburrito full
If you receive a request to bring someone a burrito you will need to acknowledge by typing:
>/cloudburrito serving
If you need a reminder of these commands, just type in:
>/cloudburrito
And that's it! Have fun!

Check out https://cloudburrito.us/ for current stats!\n")
      end
    end

    context 'help' do
      it "returns help" do
        Patron.create user_id: '1'
        post '/slack', { token: token, user_id: '1' }
        expect(last_response).to be_ok
        expect(last_response.body).to eq("Welcome to Cloud Burrito!
Version: #{`git describe`}

You can use these commands to do things:
>*join*: Join the burrito pool party.
>*feed*: Download a burrito from the cloud.
>*status*: Where is my burrito at?
>*serving*: ACK a delivery request.
>*status*: ACK receipt of burrito.
>*stats*: View your burrito stats.\n")
      end
    end

    context 'serving' do
      it "will mark an unacked burrito en route" do
        h = Patron.create user_id: '1', is_active: true
        d = Patron.create user_id: '2', is_active: true
        Package.create hungry_man: h, delivery_man: d
        post '/slack', { token: token, user_id: '2', text: "serving" }
        expect(last_response).to be_ok
        expect(last_response.body).to eq("Make haste!")
      end
    end

    context 'full' do
      it "will mark a burrito as received" do
        h = Patron.create user_id: '1', is_active: true
        d = Patron.create user_id: '2', is_active: true
        Package.create hungry_man: h, delivery_man: d
        post '/slack', { token: token, user_id: '1', text: "full" }
        expect(last_response).to be_ok
        expect(last_response.body).to eq("Enjoy!")
      end
    end

    context 'join' do
      it "checks if user is already pool" do
        Patron.create user_id: '1', is_active: true
        post '/slack', token: token, user_id: '1', text: "join"
        expect(last_response.body).to eq("You are already part of the pool party!\nRequest a burrito with */cloudburrito feed*.")
      end

      it "activates an inactive user" do
        Patron.create user_id: '1'
        post '/slack', token: token, user_id: '1', text: "join"
        expect(last_response).to be_ok
        expect(last_response.body).to eq('Please enjoy our fine selection of burritos!')
      end
    end

    context 'feed' do
      it "can't immediately feed a new patron" do
        Patron.create user_id: '1', is_active: true
        post '/slack', { token: token, user_id: '1', text: "feed" }
        expect(last_response).to be_ok
        expect(last_response.body).to match(/Stop being so greedy! Wait \d+s./)
      end

      it "can't feed a patron if there aren't any available delivery men" do
        Patron.create user_id: '1', is_active: true, force_not_greedy: true
        post '/slack', { token: token, user_id: '1', text: "feed" }
        expect(last_response).to be_ok
        expect(last_response.body).to eq("How about this? Get your own burrito.")
      end

      it "will feed a hungry man" do
        Patron.create user_id: '1', is_active: true, force_not_greedy: true
        Patron.create user_id: '2', is_active: true
        post '/slack', { token: token, user_id: '1', text: "feed" }
        expect(last_response).to be_ok
        expect(last_response.body).to eq("Burrito incoming!\nPlease use */cloudburrito full* to acknowledge that you have received your burrito.")
      end

      it "wont let a hungry man request a second burrito" do
        h = Patron.create user_id: '1', is_active: true, force_not_greedy: true
        d = Patron.create user_id: '2', is_active: true
        Package.create hungry_man: h, delivery_man: d
        post '/slack', { token: token, user_id: '1', text: "feed" }
        expect(last_response).to be_ok
        expect(last_response.body).to eq("You already have a burrito coming!")
      end

      it "wont let a delivery man request a burrito" do
        h = Patron.create user_id: '1', is_active: true, force_not_greedy: true
        d = Patron.create user_id: '2', is_active: true, force_not_greedy: true
        Package.create hungry_man: h, delivery_man: d
        post '/slack', { token: token, user_id: '2', text: "feed" }
        expect(last_response).to be_ok
        expect(last_response.body).to eq("*You* should be delivering a burrito!")
      end
    end

    context "stats" do
      it "returns stats url" do
        p = Patron.create user_id: '1'
        post '/slack', { token: token, user_id: '1', text: "stats" }
        p.reload
        expect(last_response).to be_ok
        expect(last_response.body).to eq("Use this url to see your stats.\nhttps://cloudburrito.us/user?user_id=#{p._id}&token=#{p.user_token}")
      end
    end
  end

  context "GET /user" do
    it "returns 401 without user_id" do
      get '/user'
      expect(last_response.status).to eq(401)
    end

    it "returns 401 without token" do
      Patron.create(user_id: '1')
      get '/user', user_id: '1'
      expect(last_response.status).to eq(401)
    end

    it "Can access user pages" do
      p = Patron.create(user_id: '1')
      get '/user',  token: p.user_token, user_id: p._id
      expect(last_response).to be_ok
    end
  end
end
