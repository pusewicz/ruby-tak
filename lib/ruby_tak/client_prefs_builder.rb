# frozen_string_literal: true

require "ox"

module RubyTAK
  class ClientPrefsBuilder
    def initialize(prefs)
      @prefs = prefs
    end

    def to_xml
      doc = Ox::Document.new

      instruct = Ox::Instruct.new(:xml)
      instruct[:version] = "1.0"
      instruct[:encoding] = "UTF-8"
      instruct[:standalone] = "yes"
      doc << instruct

      preferences = Ox::Element.new("preferences")

      @prefs.each do |name, entries|
        preference = Ox::Element.new("preference")
        preference[:version] = "1"
        preference[:name] = name.to_s

        entries.each do |key, value|
          entry = Ox::Element.new("entry")
          entry[:key] = key.to_s
          entry[:class] = "class java.lang.#{variable_class(value)}"
          entry << value.to_s

          preference << entry
        end

        preferences << preference
      end

      doc << preferences

      Ox.dump(doc)
    end

    def variable_class(value)
      case value
      when TrueClass, FalseClass then "Boolean"
      when Integer then "Integer"
      when String then "String"
      else
        raise "Unsupported class: #{value.class}"
      end
    end
  end
end
