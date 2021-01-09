class JiraUtil
  def client
    return @client unless @client.nil?

    options = {
      username: ENV.fetch('ATTLASIAN_EMAIL'),
      password: ENV.fetch('ATTLASIAN_TOKEN'),
      site: ENV.fetch('ATTLASIAN_URL'),
      context_path: '',
      auth_type: :basic
    }

    @client = JIRA::Client.new(options)
  end

  def board
    return @board unless @board.nil?

    board = client.Board.all.find do |board|
      board.name == ENV.fetch('JIRA_BOARD_NAME')
    end

    @board = Board.new(board)
  end

  def custom_fields
    return @custom_fields unless @custom_fields.nil?

    @custom_fields = client.Field.map_fields
  end
end
