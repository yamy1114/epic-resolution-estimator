Bundler.require
Dotenv.load
Dir.glob('./lib/**/*.rb') { |file| require_relative file }

# jira-ruby gem が noisy な warn を出すので抑制
def warn(*) end

jira_util = JiraUtil.get_instance
epics = jira_util.epics.sort_by(&:rank)

Parallel.each_with_index(epics, in_threads: 10) do |epic, i|
  puts "rank issues in #{epic.summary} (#{i+1}/#{epics.size})"
  epic.rank_issues
end
