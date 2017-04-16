require_relative '../cloudburrito'
require 'rspec'
require 'rack/test'

describe 'The CloudBurrito settings' do
  include Rack::Test::Methods

  def app
    CloudBurrito
  end

  it 'has a verification token' do
    expect(Settings.verification_token).not_to be_empty
  end

  it 'has an authentication token' do
    expect(Settings.auth_token).not_to be_empty
  end
end
