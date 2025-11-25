class AddExcludePatternsToSource < ActiveRecord::Migration[7.0]
  def change
    add_column :sources, :exclude_patterns, :json
  end
end
