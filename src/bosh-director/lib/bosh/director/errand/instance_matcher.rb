module Bosh::Director
  class Errand::InstanceMatcher
    def initialize(requested_instance_filters)
      @matched_requests = Set.new
      @filters = requested_instance_filters.map do |req|
        if req.is_a?(Hash)
          Errand::InstanceFilter.new(req['group'], req['id'], req)
        else
          Errand::InstanceFilter.new(nil,nil, req)
        end
      end
    end

    def matches?(instance, instances_in_group)
      return true if @filters.empty?
      found = false
      @filters.each do |filter|
        if filter.matches?(instance, instances_in_group)
          @matched_requests.add(filter)
          found = true
        end
      end
      found
    end

    def unmatched_criteria
      (@filters - @matched_requests.to_a).compact.map(&:original)
    end
  end

  class Errand::InstanceFilter
    attr_reader :original

    def initialize(group_name, index_or_id, original)
      @group_name = group_name
      @index_or_id = index_or_id
      @original = original
    end

    def matches?(instance, instances_in_group)
      if @index_or_id.nil? || @index_or_id.empty?
        return instance.job_name == @group_name
      end

      if @index_or_id == 'first' && instance.job_name == @group_name
        return instances_in_group.map(&:uuid).sort.first == instance.uuid
      end

      instance.job_name == @group_name &&
        (instance.uuid == @index_or_id || instance.index.to_s == @index_or_id.to_s )
    end
  end
end

