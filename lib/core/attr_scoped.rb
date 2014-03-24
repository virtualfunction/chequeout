# == Scoped Attributes
#
# This is like attr_accessor, but instead of a setter assignment method, you reuse
# the 'getter' by passing a value and block to it. This value will be set for the
# scope of the block.
#
# This is quite handy for systems where you are dealing with mini "DSL's" or
# ActiveSupport::Callbacks which doesn't allow you to pass parameters
module Chequeout::Core::AttrScoped
  extend ActiveSupport::Concern

  module ClassMethods
    # Define methods to wrap round scoped_item
    def attr_scoped(*args)
      args.each do |field|
        class_eval <<-END_CODE, __FILE__, __LINE__ + 1
          def #{field}(item = nil, &code)
            scoped_item :#{field}, item, &code
          end
        END_CODE
      end
    end
  end

  # Decide if we are reading or writing
  def scoped_item(name, item = nil, &code)
    if item and code
      set_scoped name, item, &code
    else
      scoped_items[name]
    end
  end

  # Assign a scope and run a block
  def set_scoped(name, item, &code)
    old = scoped_items[name]
    scoped_items[name] = item
    code.call
  ensure
    if old.nil?
      scoped_items.delete name
    else
      scoped_items[name] = old
    end
  end

  # Table of currently scoped items
  def scoped_items
    @scoped_items ||= Hash.new
  end
end
