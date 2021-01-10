class JiraUtil
  class CustomField
    module Key
      STORY_POINT = 'Story_Points'.freeze
      RANK = 'Rank'.freeze
    end

    def initialize(fields)
      @fields = fields
    end

    def story_point
      @fields[Key::STORY_POINT]
    end

    def rank
      @fields[Key::RANK]
    end
  end
end
