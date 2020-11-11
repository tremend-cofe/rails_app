require "nokogiri"
require "byebug"
require "axlsx"

ONE_OTHER= {
  one: "1 element",
  other: "Another number of elements"
}
WEST_SLAVIC = {
  one: "1 element",
  few: "2, 3, or 4 elements",
  other: "Another number of elements"
}
GAELIC = {
  one: "1 element",
  two: "2 elements",
  few: "3 to 6 elements",
  many: "7 to 10 elements",
  other: "Another number of elements"
}
ONE_UP_TO_TWO_OTHER = {
  "one" => "0 or 1 element",
  "other" => "Number of elements other than 1"
}
EAST_SLAVIC = {
  one: "if the number of elements ends in 1 but not with 11",
  few: "if the number of elements ends with 2, 3, 4 but not with 12, 13, 14",
  many: "if the number of elements ends with 0, 5, 6, 7, 8, 9 or 11, 12, 13, 14",
  other: "any other number of elements"
}
LITHUANIAN = {
  one: "if the number of elements ends with 1 but not with 11",
  few: "if the number of elements ends with 2 to 9, but not with 12 to 19",
  other: "any other number of elements"
}
LATVIAN = {
  one: "if the number of elements ends with 1 but not with 11",
  other: "any other number of elements"
}
MALTESE = {
  one: "1 element",
  few: "0 elements or 2-10 elements",
  many: "11-19 elements",
  other: "any other number of elements"
}
POLISH = {
  one: "1 element",
  few: "if the number of elements ends with 2, 3 or 4 but not with 12, 13, or 14",
  many: "if the number of elements ends with 0, 1, 5, 6, 7, 8, 9, 12, 13 or 14",
  other: "any other number of elements"
}
ROMANIAN = {
  one: "1 element",
  few: "if the number of elements is zero or ends with 01 to 19",
  other: "any other number of elements"
}
SLOVENIAN = {
  one: "if the number of elements is 1, 101, 201, 301...",
  two: "if the number of elements is 2, 102, 202, 302...",
  few: "if the number of elements is 3 or 4 or ends with 03 or 04 (103, 104, 203, 204...)",
  other: "any other number of elements"
}

PLURALS = {
  "bg" => ONE_OTHER,
  "cs" => WEST_SLAVIC,
  "da" => ONE_OTHER,
  "de" => ONE_OTHER,
  "el" => ONE_OTHER,
  "es" => ONE_OTHER,
  "et" => ONE_OTHER,
  "fi" => ONE_OTHER,
  "fr" => ONE_UP_TO_TWO_OTHER,
  "ga" => GAELIC,
  "hr" => EAST_SLAVIC,
  "hu" => ONE_OTHER,
  "it" => ONE_OTHER,
  "lt" => LITHUANIAN,
  "lv" => LATVIAN,
  "mt" => MALTESE,
  "nl" => ONE_OTHER,
  "pl" => POLISH,
  "pt" => ONE_OTHER,
  "ro" => ROMANIAN,
  "sk" => WEST_SLAVIC,
  "sl" => SLOVENIAN,
  "sv" => ONE_OTHER,
}

LANGS = [
    :bg, # Bulgarian
    :cs, # Czech
    :da, # Danish
    :de, # German
    :el, # Greeek
    :es, # Spanish
    :et, # Estonian
    :fi, # Finnish
    :fr, # French
    # :ga, # Gaelic (Irish)
    :hr, # Croatian
    :hu, # Hungarian
    :it, # Italian
    :lt, # Lithuanian
    :lv, # Latvian
    :mt, # Maltese
    :nl, # Dutch
    :pl, # Polish
    :pt, # Portuguese
    :ro, # Romanian
    :sk, # Slovak
    :sl, # Slovene
    :sv  # Swedish
]

def check_locales!
  all_good = true
  LANGS.each do |lang|
    unless get_plurals(lang.to_s)
      all_good = false
      puts "Missing plural rules, check https://github.com/svenfuchs/rails-i18n/blob/master/rails/pluralization/#{lang.to_s}.rb"
    end
  end
  all_good
end

def get_plurals(lang)
  rules = PLURALS[lang.to_s]
end

def filename(file)
  file_name = file.attributes["original"].value.gsub("/master/config/locales/", "")
end

def skip_file?(file)
  file_name = filename(file)

  %w(
    decidim-initiatives
    decidim-consultations
    decidim-elections
    decidim-dev
  ).any? do |skippable|
    file_name.include?(skippable)
  end
end

def unit_element?(node)
  node.name == "trans-unit"
end

def group_element?(node)
  node.name == "group"
end

def parse_unit_node(node, sheet, key = nil)
  return unless unit_element?(node)

  source_key = key || node.attributes["resname"].value
  return if source_key.include?(".admin.")

  source_node = node.children.find {|n| n.name == "source"}
  source_value = source_node.children.first.to_s

  clean_key = source_key.gsub("root.", "")
  clean_value = source_value.gsub("&lt;", "<").gsub("&gt;", ">")

  sheet.add_row([clean_key, clean_value, ""])
end

def parse_group_node(group, sheet)
  return unless group_element?(group)

  elements = group.css("trans-unit")

  raise "PROBLEM: elem: #{elements.count}, plurals: #{@plurals.count}" if elements.count != @plurals.count

  @plurals.count.times do |i|
    node = elements[i]
    plural_rule = @plurals.keys[i]

    key = node.attributes["resname"].value + "." + plural_rule.to_s

    parse_unit_node(node, sheet, key)
  end
end

def add_intro_sheet!
  @book.add_worksheet(name: "Intro") do |sheet|
    sheet.add_row(["Explanation about plural keys"])
    sheet.add_row([])
    sheet.add_row(["Some of the keys to translate include plural forms."])
    sheet.add_row(["As a guide, here's how they will be treated:"])
    sheet.add_row([])
    @plurals.each do |key, value|
      sheet.add_row([".#{key}:", value])
    end
  end
end

if check_locales!
  LANGS.each do |lang|
    lang = lang.to_s
    @plurals = get_plurals(lang)

    puts "Exporting #{lang}.xliff..."

    base_path = "/Users/marc/code/decidim-apps/crowdin-dife/exports/"
    file_path = base_path + lang + ".xliff"

    xml_document = File.read(file_path)

    doc = Nokogiri::XML(xml_document)

    package = Axlsx::Package.new
    @book = package.workbook

    add_intro_sheet!

    @book.add_worksheet(name: "Translations") do |sheet|
      sheet.add_row(["Key", "EN", "Translation"])

      doc.css("file").each do |i18n_file|
        print "Reading #{filename(i18n_file)}... "

        if skip_file?(i18n_file)
          print "SKIPPED\n"
          next
        end
        print "YAY\n"

        body = i18n_file.children.find{ |node| node.name == "body" }

        body.children.each do |node|
          next unless group_element?(node) || unit_element?(node)

          parse_unit_node(node, sheet)
          parse_group_node(node, sheet)
        end
      end
    end

    package.serialize(base_path + lang + ".xlsx")
  end
end
