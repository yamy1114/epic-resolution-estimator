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

  def achievement_table(summarized_reports)
    Terminal::Table.new do |t|
      t << [:sprint, *summarized_reports.map { |s| s[:sprint] }, 'SUM']
      t << :separator

      %i(days week_days sprint_size).each do |key|
        t << [key, *summarized_reports.map { |s| s[key] }, summarized_reports.sum { |s| s[key] }]
      end

      t << :separator

      %i(resolved_points interrupted_points progress_points unburnable_points).each do |key|
        t << [key, *summarized_reports.map { |s| s[key].round(1) }, summarized_reports.sum { |s| s[key] }.round(1)]
      end
    end
  end
end
