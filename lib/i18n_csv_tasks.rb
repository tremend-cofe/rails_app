require 'i18n/tasks/commands'
require 'csv'
require "byebug"

# PREVIOUS STEPS
#
# Open the `i18n-tasks` gem and edit this:
#
# lib/i18n/tasks/data/file_system_base.rb:64
#
#     path = $newfilepath
#
# This will make sure you're saving the file in the path specified in the
# `$newfilepath` variable.
module I18nCsvTasks
  include ::I18n::Tasks::Command::Collection

  class WrongRowNumber < StandardError; end

  cmd :csv_import, desc: 'import translations from CSV'
  def csv_import(opts = {})
    base_config = i18n.data.config[:write].dup
    files = Dir[i18n.config["csv"]["import_pattern"]]
    wrong_files = []
    files.each do |file|
      begin
        p file
        csv = open(file).read.force_encoding('UTF-8')
        filename = file.split("/").last
        locale = filename.split(".").first.downcase
        decidim_module = filename.split(".")[1].downcase

        translations = []
        CSV.parse(csv, headers: true) do |row|
          key = row[0]
          translated_value = row[2]
          # raise WrongRowNumber if row.count < 3
          next unless key && translated_value

          translations << [[locale, key].join("."), translated_value]
        end

        # # Uncomment this in order to attempt to recognise entries that are likely symbols pointing to
        # # other translations, intended to be rendered in your .yml with a preceding colon:
        # translations.map! { |t| [t.first, (t.last&.=~ /^(?=.*\.)[a-z0-9_\.]+$/) ? t.last.to_sym : t.last] }
        $newfilepath = "config/locales/#{locale}.#{decidim_module}.yml"
        i18n.data.config[:write] = ["config/locales/#{locale}.#{decidim_module}.yml"]
        i18n.data.set locale, I18n::Tasks::Data::Tree::Siblings.from_flat_pairs(translations)
        i18n.data.config[:write] = base_config.dup
      rescue WrongRowNumber
        wrong_files << file
      end
    end
    p wrong_files if wrong_files.any?
  end
end

I18n::Tasks.add_commands I18nCsvTasks
