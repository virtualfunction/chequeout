::NEWLINE = "\n" unless defined? ::NEWLINE

# This is a short term evil hack that works round the MultipleIncludedBlocks
# error in Rails >= 4.1. In the long term we need to phase out the use of
# Module#when_included in favour of a more explicit feature injection
# system that doesn't wreck dependency havok!
ActiveSupport::Concern.class_eval do
  def included(base = nil, &block)
    if base.nil?
      # raise MultipleIncludedBlocks if instance_variable_defined?(:@_included_block)
      @_included_block = block
    else
      super
    end
  end
end

# == Modify modules to automatically utilise ActiveSupport::Concern
# Also allows multiple code blocks to run when included via then when_included method
module Chequeout::Core::Concerned
  def when_included(&code)
    unless self < ActiveSupport::Concern
      extend ActiveSupport::Concern
      orignal = self
      included do
        orignal.included_list.each { |item| instance_eval &item }
      end
    end
    included_list << code
  end

  protected

  def included_list
    @included_list ||= Set.new
  end
end

Module.__send__ :include, Chequeout::Core::Concerned
