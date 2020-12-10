require 'i18n/tasks/commands'
require 'csv'
require "byebug"

# PREVIOUS STEPS
#
# Make sure you're using `i18n-tasks` from this repository:
#
# https://github.com/tremend-cofe/i18n-tasks
module I18nCsvTasks
  include ::I18n::Tasks::Command::Collection

  class WrongRowNumber < StandardError; end

  cmd :csv_import, desc: 'import translations from CSV'
  def csv_import(opts = {})
    base_config = i18n.data.config[:write].dup
    files = Dir[i18n.config["csv"]["import_pattern"]]
    byebug
    wrong_files = []
    files.each do |file|
      begin
        p file
        csv = open(file).read.force_encoding('UTF-8')
        filename = file.split("/").last
        locale = filename.split(".").first.downcase
        decidim_module = "update_locales"

        translations = []
        CSV.parse(csv, headers: false) do |row|
          key = row[0]
          translated_value = row.compact.last
          raise WrongRowNumber if row.count < 3
          next unless key && translated_value

          translations << [[locale, key].join("."), translated_value]
        end

        tree = I18n::Tasks::Data::Tree::Siblings.from_flat_pairs(translations)
        newfilepath = "locales/#{locale}.#{decidim_module}.yml"

        out_file = File.open(newfilepath, "w") { |f| f.write tree.inspect }
      rescue WrongRowNumber
        wrong_files << file
      end
    end
    p wrong_files if wrong_files.any?
  end
end

I18n::Tasks.add_commands I18nCsvTasks
