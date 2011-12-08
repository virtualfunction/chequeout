require 'active_record/connection_adapters/abstract/schema_definitions'

module Chequeout::Database
  
  # == Added to table defintion
  module Schema
    # Delegate DDL actions
    def chequeout(*actions)
      Database.load_all
      actions.each do |label|
        Database.action! label, self
      end
    end
    
    def index(*opts)
      # TODO: This really wasn't well thought out Jase. Ignore for now.
    end
  end

  module_function
  
  # Register table DDL actions
  def register(label, &code)
    action(label).add code
  end
  
  # Perform given DDL actions on a table
  def action!(label, table)
    actions = action label
    raise 'There is nothing defined' if actions.empty?
    actions.each do |code|
      table.instance_eval &code
    end
  end
  
  # Registry of DDL actions
  def actions
    @action ||= Hash.new
  end
  
  # Get action(s) for a label
  def action(label)
    actions[label.to_sym] ||= Set.new
  end

  # File list that might potentionally contain DB DDL info
  def load_file_list
    Dir['%s/{lib,app/models}/**/*.rb' % root]
  end
  
  # Load files once only
  def load_all
    @loaded_source ||= load_file_list.each { |file| require_dependency file }
  end
  
  def root
    Rails.root
  end
end

::Database = Chequeout::Database unless defined? ::Database
ActiveRecord::ConnectionAdapters::TableDefinition.__send__ :include, Database::Schema

