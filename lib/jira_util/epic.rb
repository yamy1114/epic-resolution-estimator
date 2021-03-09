class JiraUtil
  class Epic < Base
    ISSUE_SEARCH_MAX_RESULTS = 1_000
    RANK_ISSUE_MAX_UNIT = 50

    def summarized
      {
        summary: summary,
        point: point,
        rank: rank,
      }
    end

    def rank_issues
      # 今の実装だと 100 件以上の issue は取れない
      issue_keys = jira_util.client.Issue.jql(issues_search_query).map(&:key)

      issue_keys.each_slice(RANK_ISSUE_MAX_UNIT).reverse_each do |keys|
        request_body = {
          issues: keys,
          rankAfterIssue: key,
          rankCustomFieldId: jira_util.custom_fields.rank.match(/\d+/)[0].to_i
        }

        jira_util.client.put('/rest/agile/1.0/issue/rank', request_body.to_json)
      end
    end

    def rank
      fields[jira_util.custom_fields.rank]
    end

    private

    def jira_util
      @jira_util ||= JiraUtil.get_instance
    end

    def point
      fields[jira_util.custom_fields.story_point]
    end

    def issues_search_query
      [
        "project = #{ENV.fetch('PROJECT_NAME')}",
        'issuetype != epic',
        '(status != Done OR status = Done AND resolved > -12d)',
        "'Epic Link' = #{key}"
      ].join(' AND ')
    end
  end
end
