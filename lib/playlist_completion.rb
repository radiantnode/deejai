require_relative "openai"

class PlaylistCompletion
  AI_MODEL = "gpt-3.5-turbo"
  AI_TEMPERATURE = 0.7
  AI_SYSTEM_MESSAGE = <<-MESSAGE
    You are a music assistant. You return lists of songs. The playlist should have 20 songs. ALways respond with JSON in this format:

    ```
    {
      "title": "<a fun name for the playlist>",
      "tracks": [
        {
          "track": "<song title>",
          "artist": "<artist>"
        }
      ]
    }
    ```
  MESSAGE

  class Response
    JSON_MATCHER = /{.*}/m

    class NoChoiceAvailable < StandardError; end
    class PlaylistNotParsable < StandardError; end

    def initialize(data)
      @data = data
      @choice = @data.dig('choices', 0, 'message', 'content')

      raise NoChoiceAvailable unless @choice
    end

    def playlist
      begin
        @playlist ||= JSON.parse(@choice[JSON_MATCHER])
      rescue JSON::ParserError
        raise PlaylistNotParsable, "Unable to parse JSON from AI response: #{@choice.inspect}"
      end
    end
  end

  def initialize(prompt)
    @openai = OpenAI.new
    @prompt = prompt
  end

  def perform
    response = completions_response
    return Response.new(response.parsed_response) if response.ok?
  end

  private

  def completions_response
    @openai.completions({
      model: AI_MODEL,
      temperature: AI_TEMPERATURE,
      messages: [
        {
          role: "system",
          content: AI_SYSTEM_MESSAGE
        },
        {
          role: "user", 
          content: @prompt
        }
      ]
    })
  end
end
