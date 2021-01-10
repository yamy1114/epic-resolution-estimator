class JiraUtil
  class Epic < Base
    def summarized
      jira_util = JiraUtil.new

      {
        summary: summary,
        point: fields[jira_util.custom_fields.story_point],
        rank: fields[jira_util.custom_fields.rank]
      }
    end
  end
end
