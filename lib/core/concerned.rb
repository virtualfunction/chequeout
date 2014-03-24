::NEWLINE = "\n" unless defined? ::NEWLINE

# == Modify modules to automatically utilise ActiveSupport::Concern
# Also allows multiple code blocks to run when included via then when_included method
module Chequeout::Core::Concerned
  def when_included(&code)
    unless self < ActiveSupport::Concern
      extend ActiveSupport::Concern
      orignal = self
      included do
        puts orignal.name
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
