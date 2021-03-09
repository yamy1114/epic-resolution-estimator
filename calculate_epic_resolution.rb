Bundler.require
require 'active_support/all'

Dotenv.load

Dir.glob('./lib/**/*.rb') { |file| require_relative file }

# jira-ruby gem が noisy な warn を出すので抑制
def warn(*) end

puts "base_sprint_days: #{JiraUtil::BASE_SPRINT_DAYS}"

jira_util = JiraUtil.get_instance

# calculate achievement
achievement_sprints = jira_util.board.achievement_sprints
summarized_sprint_reports = achievement_sprints.map { |sprint| sprint.summarized_report }
achievement_table = jira_util.achievement_table(summarized_sprint_reports)

puts
puts '## achievement'
puts achievement_table

# estimate future epic resolution
summarized_epics = jira_util.epics.map(&:summarized).sort_by { |epic| epic[:rank] }
last_sprint_capacities = jira_util.last_sprint_capacities(summarized_sprint_reports)

estimated_sprint_capacities = {
  average: last_sprint_capacities.sum / last_sprint_capacities.size,
  worst: last_sprint_capacities.min,
  best: last_sprint_capacities.max
}

sprint_resolution_estimations_hash = estimated_sprint_capacities.map do |type, capacity|
  [type, jira_util.sprint_resolution_estimations(summarized_epics, capacity)]
end.to_h

estimation_table = jira_util.estimation_table(sprint_resolution_estimations_hash)

puts
puts '## estimation'
puts "sprint_capacity:"
estimated_sprint_capacities.each do |type, capacity|
  puts "#{type}: #{capacity.round(1)}".send(JiraUtil::TEXT_COLOR[type])
end
puts estimation_table
