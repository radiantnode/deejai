require 'httparty'

class OpenAI
  include HTTParty
  base_uri "https://api.openai.com/v1"

  OPENAI_API_KEY = ENV['OPENAI_API_KEY']

  def initialize
    @options = {
      timeout: 60 * 3, # OpenAI sometimes take a while to respond
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer #{OPENAI_API_KEY}"
      }
    }
  end

  def completions(payload)
    self.class.post("/chat/completions", @options.merge(body: payload.to_json))
  end
end
