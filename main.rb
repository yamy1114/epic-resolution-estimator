Bundler.require
Dotenv.load

Dir.glob('./lib/**/*.rb') { |file| require_relative file }

# jira-ruby gem が noisy な warn を出すので抑制
def warn(*) end

ACHIEVEMENT_SIZE = 5
PREDICTION_SIZE = 5
MEMBER_COUNT = 5
BASE_SPRINT_DAYS = 10

jira_util = JiraUtil.new

board = jira_util.board
achievement_sprints = board.achievement_sprints(ACHIEVEMENT_SIZE)
summarized_sprint_reports = achievement_sprints.map { |sprint| sprint.summarized_report(MEMBER_COUNT) }
achievement_table = jira_util.achievement_table(summarized_sprint_reports)

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

progress_points_sum = summarized_sprint_reports.sum { |s| s[:progress_points] }
sprint_size_sum = summarized_sprint_reports.sum { |s| s[:sprint_size] }
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
