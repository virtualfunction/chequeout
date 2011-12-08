module Eventable
  module ClassMethods
    def event_list
      @event_list ||= Set.new
    end
    
    def register_callback_events(*list)
      event_list.merge list
      define_model_callbacks *list
    end
  end
  extend ActiveSupport::Concern
end

ActiveRecord::Base.__send__ :include, Eventable
