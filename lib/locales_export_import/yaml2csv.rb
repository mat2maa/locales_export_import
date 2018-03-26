require 'yaml'
require 'csv'

module LocalesExportImport
  module Yaml2Csv
    extend self

    def convert(input_files, output_file, pattern = nil)
      @arr = ::Array.new
      @locales = ::Array.new
      input_files.each do |input_file|
        input_data = load_file(::File.join(input_file))
        unless input_data.is_a?(Hash)
          raise ::I18n::InvalidLocaleData.new(input_file, 'expects it to return a hash, but does not')
        end
        input_data.keys.each do |key|
          # 1st level should contain only one key -- locale code
          @locales << key
          construct_csv_row(key, input_data[key], pattern)
        end
      end
      ::CSV.open(::File.join(output_file), 'wb') do |csv|
        # headers
        csv << ['key', *@locales.map {|l| "#{l}_value"}]
        @arr.each { |row| csv << row }
      end
    end

    def construct_csv_row(key, value, pattern)
      case value
      when ::String
        if !pattern || value =~ pattern
          if @locales.length > 1 && (existing_key_index = @arr.find_index {|el| el.first.partition('.').last == key.partition('.').last})
            @arr[existing_key_index] << value
          else
            @arr << [key, value]
          end
        end
      when ::Array
        # ignoring arrays to avoid having duplicate keys in CSV
        # value.each { |v| construct_csv_row(key, v) }
      when ::Hash
        value.keys.each { |k| construct_csv_row("#{key}.#{k}", value[k], pattern) }
      end
    end

    private

    # Loads a single translations file by delegating to #load_rb or
    # #load_yml depending on the file extension and directly merges the
    # data to the existing translations. Raises I18n::UnknownFileType
    # for all other file extensions.
    def load_file(filename)
      type = ::File.extname(filename).tr('.', '').downcase
      raise ::I18n::UnknownFileType.new(type, filename) unless respond_to?(:"load_#{type}", true)
      data = send(:"load_#{type}", filename)
    end

    # Loads a plain Ruby translations file. eval'ing the file must yield
    # a Hash containing translation data with locales as toplevel keys.
    def load_rb(filename)
      stringify_values(eval(::IO.read(filename)))
    end

    def stringify_values(obj)
      temp = {}
      obj.each do |k, v|
        if v.is_a?(Hash)
          temp[k] = stringify_values(v)
        else
          temp[k] = v.to_s
        end
      end
      temp
    end

    # Loads a YAML translations file. The data must have locales as
    # toplevel keys.
    def load_yml(filename)
      begin
        ::YAML.load_file(filename)
      rescue TypeError, ScriptError, StandardError => e
        raise ::I18n::InvalidLocaleData.new(filename, e.inspect)
      end
    end

  end
end
