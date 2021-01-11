Bundler.require
require 'active_support/all'

Dotenv.load

Dir.glob('./lib/**/*.rb') { |file| require_relative file }

# jira-ruby gem が noisy な warn を出すので抑制
def warn(*) end

puts "member_count: #{JiraUtil::MEMBER_COUNT}"
puts "base_sprint_days: #{JiraUtil::BASE_SPRINT_DAYS}"

jira_util = JiraUtil.new

# calculate achievement
achievement_sprints = jira_util.board.achievement_sprints
summarized_sprint_reports = achievement_sprints.map { |sprint| sprint.summarized_report }
achievement_table = jira_util.achievement_table(summarized_sprint_reports)

puts
puts '## achievement'
puts achievement_table

# estimate future epic resolution
summarized_epics = jira_util.epics.map(&:summarized).sort_by { |epic| epic[:rank] }
estimated_sprint_capacity = jira_util.estimated_sprint_capacity(summarized_sprint_reports)
future_sprint_estimations = jira_util.future_sprint_estimations(summarized_epics, estimated_sprint_capacity)
estimation_table = jira_util.estimation_table(future_sprint_estimations)

puts
puts '## estimation'
puts "sprint_capacity: #{estimated_sprint_capacity.round(1)}"
puts estimation_table
