Bundler.require
Dotenv.load

# jira-ruby gem が noisy な warn を出すので抑制
def warn(*) end

ACHIEVEMENT_SIZE = 5
PREDICTION_SIZE = 5
MEMBER_COUNT = 5
BASE_SPRINT_DAYS = 10

# get client
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

custom_fields = client.Field.map_fields

# get board & achievement sprints
def get_all_sprints(board)
  all_sprints = []
  start_at = 0
  max_results = 50

  loop do
    searched_sprints = board.sprints(startAt: start_at)
    all_sprints += searched_sprints
    break if searched_sprints.empty?

    start_at += max_results
  end

  all_sprints
end

def select_work_sprints(sprints)
  sprints.select do |sprint|
    sprint.name.match(/^Bear\/Lego Sprint \d+$/)
  end
end

def get_working_sprint_index(sprints)
  sprints.find_index do |sprint, i|
    ['active', 'future'].include?(sprint.state)
  end
end

board = client.Board.all.find do |board| board.name == ENV['JIRA_BOARD_NAME'] end
all_sprints = get_all_sprints(board)
work_sprints = select_work_sprints(all_sprints)
working_sprint_index = get_working_sprint_index(work_sprints)
achievement_sprints = work_sprints[(working_sprint_index - ACHIEVEMENT_SIZE)..(working_sprint_index - 1)]

# calculate achievement
def reject_unburnable_issues(issues)
  issues.reject do |issue|
    issue['epicField']['text'].match(/\[U\]/)
  end
end

def select_unburnable_issues(issues)
  issues - reject_unburnable_issues(issues)
end

def extract_completed_issues(report)
  reject_unburnable_issues(report.completedIssues)
end

def extract_incompleted_issues(report)
  reject_unburnable_issues(report.issuesNotCompletedInCurrentSprint)
end

def calculate_completed_issues_resolved_points(issues)
  issues.map do |issue|
    issue.dig('currentEstimateStatistic', 'statFieldValue', 'value') || 0
  end.sum
end

def calculate_incompleted_issues_resolved_points(issues)
  issues.map do |issue|
    estimated_point = issue.dig('estimateStatistic', 'statFieldValue', 'value')
    current_point = issue.dig('currentEstimateStatistic', 'statFieldValue', 'value')

    estimated_point != nil && current_point != nil && estimated_point != current_point && current_point != 0 ? estimated_point - current_point : 0
  end.sum
end

def extract_interrupted_issues(issues, added_during_sprint_issue_keys, sprint)
  issues.select do |issue|
    issue['epicField']['text'].match(/\[P\]/) || (added_during_sprint_issue_keys.include?(issue['key']) && (sprint.startDate.to_date..sprint.completeDate.to_date).include?(client.Issue.find(issue['key']).created.to_date))
  end
end

def calculate_interrupted_issues_points(issues)
  issues.map do |issue|
    estimated_point = issue.dig('estimateStatistic', 'statFieldValue', 'value')
    current_point = issue.dig('currentEstimateStatistic', 'statFieldValue', 'value')

    next 0 if current_point == 0
    next [estimated_point, current_point].max if estimated_point != nil && current_point != nil

    estimated_point || current_point || 0
  end.sum
end

pretty_sprint_reports = achievement_sprints.map do |sprint|
  report = sprint.sprint_report

  completed_issues = extract_completed_issues(report)
  completed_issues_resolved_points = calculate_completed_issues_resolved_points(completed_issues)
  incompleted_issues = extract_incompleted_issues(report)
  incompleted_issues_resolved_points = calculate_incompleted_issues_resolved_points(incompleted_issues)
  resolved_points = completed_issues_resolved_points + incompleted_issues_resolved_points

  added_during_sprint_issue_keys = report.issueKeysAddedDuringSprint
  completed_interrupted_issues = extract_interrupted_issues(completed_issues, added_during_sprint_issue_keys, sprint)
  completed_interrupted_issues_resolved_points = calculate_completed_issues_resolved_points(completed_interrupted_issues)
  incompleted_interrupted_issues = extract_interrupted_issues(incompleted_issues, added_during_sprint_issue_keys, sprint)
  incompleted_interrupted_issues_resolved_points = calculate_incompleted_issues_resolved_points(incompleted_interrupted_issues)
  interrupted_points = completed_interrupted_issues_resolved_points + incompleted_interrupted_issues_resolved_points

  unburnable_issues = select_unburnable_issues(report.completedIssues)
  unburnable_issues_points = calculate_completed_issues_resolved_points(unburnable_issues)

  open_date = sprint.startDate.to_date
  close_date = sprint.completeDate.to_date
  days = (close_date - open_date).to_i
  week_days = days - open_date.upto(close_date).count { |date| [0, 6].include?(date.wday) }
  sprint_size = week_days * MEMBER_COUNT

  {
    sprint: sprint.name.match(/\d+/)[0],
    resolved_points: resolved_points,
    interrupted_points: interrupted_points,
    progress_points: resolved_points - interrupted_points,
    unburnable_issues_points: unburnable_issues_points,
    days: days,
    week_days: week_days,
    sprint_size: sprint_size,
  }
end

achievement_table = Terminal::Table.new do |t|
  %i(sprint).each do |key|
    t << [
      key,
      *pretty_sprint_reports.map { |s| s[key] },
      'SUM'
    ]
  end

  t << :separator

  %i(resolved_points interrupted_points progress_points unburnable_issues_points).each do |key|
    t << [
      key,
      *pretty_sprint_reports.map { |s| s[key].round(1) },
      pretty_sprint_reports.sum { |s| s[key] }.round(1)
    ]
  end

  t << :separator

  %i(days week_days sprint_size).each do |key|
    t << [
      key,
      *pretty_sprint_reports.map { |s| s[key] },
      pretty_sprint_reports.sum { |s| s[key] }
    ]
  end
end

puts
puts '## achievement'
puts achievement_table

# predict future sprint progress
epics = client.Issue.jql('project = BEAR AND issuetype = epic AND status != Done', max_results: 1000)

story_point_custom_field_id = custom_fields['Story_Points']
rank_custom_field_id = custom_fields['Rank']

pretty_epics = epics.map do |epic|
  {
    summary: epic.summary,
    point: epic.fields[story_point_custom_field_id],
    link: "https://nttcom.atlassian.net/browse/#{epic.key}",
    rank: epic.fields[rank_custom_field_id]
  }
end.sort_by { |epic| epic[:rank] }

start_sprint_index = achievement_sprints.last.name.match(/\d+/).to_s.to_i + 1
start_sprint_open_date = 7.times do |i|
  today = Date.today
  break today - i if (today - i).wday == 2
end

sprint_points_list = PREDICTION_SIZE.times.map do |i|
  open_date = start_sprint_open_date + i * 14
  close_date = start_sprint_open_date + (i + 1) * 14 - 1
  {
    sprint: start_sprint_index + i,
    points: [],
    period: "#{open_date.month}/#{open_date.day}~#{close_date.month}/#{close_date.day}"
  }
end

progress_points_sum = pretty_sprint_reports.sum { |s| s[:progress_points] }
sprint_size_sum = pretty_sprint_reports.sum { |s| s[:sprint_size] }
sprint_capacity = progress_points_sum / sprint_size_sum * BASE_SPRINT_DAYS * MEMBER_COUNT

pretty_epics.each do |epic|
  remaining_point = epic[:point] || 0.0

  sprint_points_list.each do |sprint_points|
    remaining_capacity = sprint_capacity - sprint_points[:points].sum

    if remaining_point <= remaining_capacity
      resolved_point = remaining_point
      remaining_point = 0.0
    else
      resolved_point = remaining_capacity
      remaining_point -= remaining_capacity
    end

    sprint_points[:points] << resolved_point
  end
end

prediction_table = Terminal::Table.new do |t|
  t << ['sprint', *sprint_points_list.map { |sp| sp[:sprint] }]
  t << ['period', *sprint_points_list.map { |sp| sp[:period] }]
  t << :separator

  pretty_epics.each_with_index do |epic, i|
    t << [epic[:summary], *sprint_points_list.map { |sp| sp[:points][i] == 0 ? '' : sp[:points][i].round(1) }]
  end
end

puts
puts '## prediction'
puts "sprint_capacity: #{sprint_capacity.round(1)}"
puts prediction_table
