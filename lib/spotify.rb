require "concurrent-ruby"
require "httparty"

class Spotify
  include HTTParty
  base_uri "https://api.spotify.com/v1"

  USER_ID = ENV['SPOTIFY_USER_ID']
  SPOTIFY_API_KEY = ENV['SPOTIFY_API_KEY']
  RATE_LIMIT_STATUS_CODE = 429
  MAX_RETRIES = 3

  def initialize
    @options = {
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer #{SPOTIFY_API_KEY}"
      }
    }
  end

  def me
    self.class.get("/me", @options)
  end

  def search(query, type: 'track', limit: 1)
    retryable do
      self.class.get("/search", @options.merge({
        query: {
          q: query,
          type: type,
          limit: limit
        }
      }))
    end
  end

  def concurrent_search(queries = [], *args)
    results = []

    Concurrent::Array.new(queries.each_slice(10).to_a).each do |query_batch|
      promises = query_batch.map do |query|
        Concurrent::Promise.execute do
          search(query, *args)
        end
      end
    
      results.concat(promises.map(&:value))
    end

    results
  end

  def create_playlist(name, public: false)
    self.class.post("/users/#{USER_ID}/playlists", @options.merge({
      body: {
        name: name,
        public: public
      }.to_json
    }))
  end

  def add_to_playlist(playlist_id, track_uris = [])
    self.class.post("/playlists/#{playlist_id}/tracks", @options.merge({
      body: {
        uris: track_uris
      }.to_json
    }))
  end

  private

  # In the event that Spotify throttles our request due to rate
  # limits try again after Retry-After has elapsed.
  def retryable(limit: MAX_RETRIES, &block)
    retries = 0
    response = nil

    loop do
      response = yield
      break if response.code != RATE_LIMIT_STATUS_CODE || retries >= limit
      sleep response.headers['Retry-After'].to_i
      retries += 1
    end

    return response
  end
end
