class CreateSchema < ActiveRecord::Migration
  def change
    Context.applied_database_scheme.each do |name, blocks|
      model = Context.model name
      create_table model.table_name, force: true do |table|
        blocks.each do |code|
          instance_exec table, &code
        end
      end
    end
  end
end
