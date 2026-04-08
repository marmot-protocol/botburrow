class RemoveStaticAndTemplateResponseTypes < ActiveRecord::Migration[8.1]
  def up
    # Convert template (1) commands to script (3):
    # Transform {{var}} interpolation to Ruby string interpolation and wrap in double quotes.
    execute(<<~SQL).each do |row|
      SELECT id, response_text FROM commands WHERE response_type = 1
    SQL
      id = row["id"]
      text = row["response_text"]
      converted = text
        .gsub('{{author}}', '#{author}')
        .gsub('{{args}}', '#{args}')
        .gsub('{{bot_name}}', '#{bot_name}')
        .gsub('{{timestamp}}', '#{Time.current.iso8601}')

      # Escape existing double quotes, then wrap in double quotes for Ruby interpolation
      escaped = converted.gsub('"', '\\"')
      wrapped = %("#{escaped}")

      execute "UPDATE commands SET response_text = #{quote(wrapped)}, response_type = 3 WHERE id = #{id}"
    end

    # Convert static (0) commands to script (3):
    # Wrap response_text in double quotes so bare text becomes a Ruby string literal.
    execute(<<~SQL).each do |row|
      SELECT id, response_text FROM commands WHERE response_type = 0
    SQL
      id = row["id"]
      text = row["response_text"]
      escaped = text.gsub('\\', '\\\\\\\\').gsub('"', '\\"')
      wrapped = %("#{escaped}")

      execute "UPDATE commands SET response_text = #{quote(wrapped)}, response_type = 3 WHERE id = #{id}"
    end

    # Change column default from 0 (static) to 3 (script)
    change_column_default :commands, :response_type, from: 0, to: 3
  end

  def down
    change_column_default :commands, :response_type, from: 3, to: 0
    # Note: template->script and static->script conversions are lossy
  end

  private

  def quote(value)
    ActiveRecord::Base.connection.quote(value)
  end
end
