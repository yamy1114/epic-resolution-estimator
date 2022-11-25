class JiraUtil
  ACHIEVEMENT_SIZE = 5.freeze
  ESTIMATION_SIZE = 5.freeze
  BASE_SPRINT_DAYS = 10.freeze

  EPIC_SEARCH_QUERY = "project = #{ENV.fetch('PROJECT_NAME')} AND issuetype = epic AND status != Done".freeze
  EPIC_SEARCH_MAX_RESULTS = 1_000

  TEXT_COLOR = {
      average: :white,
      worst: :blue,
      best: :light_red
  }.freeze

  def self.get_instance
    @instance ||= self.new
  end

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

    board_id_file_name = 'tmp/board_id'

    if File.exist?(board_id_file_name)
      board = client.Board.find(File.read(board_id_file_name).to_i)
    else
      board = client.Board.all.find do |board|
        board.name == ENV.fetch('JIRA_BOARD_NAME')
      end

      File.write(board_id_file_name, board.id)
    end

    @board = Board.new(board)
  end

  def epics
    return @epics unless @epics.nil?

    @epics = client.Issue.jql(EPIC_SEARCH_QUERY, max_results: EPIC_SEARCH_MAX_RESULTS).map do |epic|
      Epic.new(epic)
    end
  end

  def custom_fields
    return @custom_fields unless @custom_fields.nil?

    @custom_fields = CustomField.new(client.Field.map_fields)
  end

  def achievement_table(summarized_reports)
    Terminal::Table.new do |t|
      t << [:sprint, *summarized_reports.map { |s| s[:sprint] }]
      t << [:work_days, *summarized_reports.map { |s| s[:work_days].round(1) }]
      t << :separator

      %i(resolved_points interrupted_points progress_points improvement_points).each do |key|
        t << [key, *summarized_reports.map { |s| s[key].round(1) }]
      end

      t << [:improvement_percent, *summarized_reports.map { |s| "#{(s[:improvement_points] / s[:progress_points] * 100).round(1)}%" }]
    end
  end

  def last_sprint_capacities(summarized_reports)
    summarized_reports.map do |report|
      report[:progress_points] / report[:work_days] * BASE_SPRINT_DAYS
    end
  end

  def sprint_resolution_estimations(summarized_epics, base_sprint_capacity)
    start_sprint_index = board.working_sprint.index
    start_sprint_open_time = board.working_sprint.nil? ? Time.now : board.working_sprint.open_time

    sprint_estimations = ESTIMATION_SIZE.times.map do |i|
      open_time = start_sprint_open_time + i * 2.weeks
      close_time = start_sprint_open_time + (i + 1) * 2.weeks - 1

      {
        sprint: start_sprint_index + i,
        epics: [],
        period: "#{open_time.month}/#{open_time.day}~#{close_time.month}/#{close_time.day}",
        work_days: TimeUtil.work_days(open_time, close_time)
      }
    end

    summarized_epics.each do |epic|
      remaining_point = epic[:point] || 0.0

      sprint_estimations.each do |sprint_estimation|
        sprint_capacity = base_sprint_capacity / BASE_SPRINT_DAYS * sprint_estimation[:work_days]
        remaining_capacity = sprint_capacity - sprint_estimation[:epics].sum { |e| e[:resolved_points] || 0 }

        if remaining_point <= remaining_capacity
          resolved_point = remaining_point
          remaining_point = 0.0
        else
          resolved_point = remaining_capacity
          remaining_point -= remaining_capacity
        end

        sprint_estimation[:epics] << {
          summary: epic[:summary],
          resolved_points: resolved_point
        }
      end
    end

    sprint_estimations
  end

  def estimation_table(sprint_resolution_estimations_hash)
    sprint_indexes = sprint_resolution_estimations_hash[:average].map { |sp| sp[:sprint] }
    sprint_periods = sprint_resolution_estimations_hash[:average].map { |sp| sp[:period] }
    sprint_work_dayss = sprint_resolution_estimations_hash[:average].map { |sp| sp[:work_days].round(1) }
    epic_summaries = sprint_resolution_estimations_hash[:average].first[:epics].map { |epic| epic[:summary] }
    sprint_count = sprint_resolution_estimations_hash[:average].size

    Terminal::Table.new do |t|
      t << [:sprint, *sprint_indexes]
      t << [:period, *sprint_periods]
      t << [:work_days, *sprint_work_dayss]
      t << :separator

      epic_summaries.each_with_index do |epic_summary, epic_index|
        t << [
          epic_summary,
          *sprint_count.times.map do |sprint_index|
            points_for_display = sprint_resolution_estimations_hash.map do |type, estimations|
              resolved_points = estimations[sprint_index][:epics][epic_index][:resolved_points]
              resolved_points == 0 ? nil : resolved_points.round(1).to_s.send(TEXT_COLOR[type])
            end

            points_for_display.compact.join(' ')
          end
        ]
      end
    end
  end
end
