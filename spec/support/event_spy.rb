# Used to spy on events
module EventSpy

  def event_history
    @_event_history ||= Hash.new 0
  end
  
  def events_watched
    @_watched_events ||= Set.new
  end
  
  def spy_on(*events)
    options = events.extract_options!
    @_event_history = options[:history] || event_history
    # Iterate events, skipping ones we already watch
    (events - events_watched.to_a).uniq.each do |item|
      event = item.to_sym
      events_watched << event
      # Hook in a callback, but just for this object
      self.singleton_class.class_eval do
        set_callback event, :before do 
          event_history[event] += 1
        end
      end
    end
    event_history.clear
    self
  end
end

ActiveRecord::Base.__send__ :include, EventSpy
