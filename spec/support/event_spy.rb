# Used to spy on ActiveSupport::Callback events
# 
# I farking hate this code, it's a little brittle and assumes some Voodoo exists 
# in respect to block binding
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
    oid = object_id
    # Iterate events, skipping ones we already watch
    (events - events_watched.to_a).uniq.each do |item|
      event = item.to_sym
      events_watched << event
      # Hook in a callback, but just for this object
      self.class.class_eval do
        # Since Rails 3.2.x we need to define a named method as callbacks event 
        # queues are compiled in some way
        name = 'before_event_history_%s_%d' % [ event, rand(10_000_000) ]
        define_method name do
          event_history[event] += 1
        end
        set_callback event, :before, name.to_sym, :if => lambda { |record| oid == record.object_id }
      end
    end
    event_history.clear
    self
  end
end

ActiveRecord::Base.__send__ :include, EventSpy
