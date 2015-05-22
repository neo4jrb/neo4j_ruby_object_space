require 'csv'
require 'json'
require 'colored'
require 'set'

class Neo4jObjectSpaceDumper
  def initialize(base_path = '.')
    @object_ids = Set.new

    @base_path = base_path
    @csv_paths = {}
    @csvs = {}
    %i(objects instance_variables object_classes class_modules).each do |file_base|
      path = File.join(@base_path, "#{file_base}.csv")
      @csv_paths[file_base] = path
    end
  end

  def setup_csvs
    @csv_paths.each do |file_base, path|
      @csvs[file_base] = CSV.open(path, 'wb', col_sep: "\t", row_sep: "\n", quote_char: "'")
    end

    @csvs[:objects] << ['object_id:ID', 'inspect', ':LABEL']
    @csvs[:instance_variables] << [':START_ID', ':END_ID', 'variable']
    @csvs[:object_classes] << [':START_ID', ':END_ID']
    @csvs[:class_modules] << [':START_ID', ':END_ID']
  end

  def object_space_to_neo4j_csvs
    ObjectSpace.each_object do |object|
      instance_variables = object.instance_variables.each_with_object({}) do |var, h|
        h[var] = object.instance_variable_get(var)
      end

      add_object(object)

      instance_variables.each do |var, other_object|
        add_object(other_object)

        add_to_csv(:instance_variables, [object.object_id, other_object.object_id, var])
      end


    end
  ensure
    @csvs.values.each(&:close)
  end

  def add_object(object)
    return false if @object_ids.include?(object.object_id)

    @object_ids << object.object_id

    labels = ['Object']
    labels << ['Class'] if object.class == Class
    labels << ['Module'] if object.class == Module

    add_to_csv(:objects, [
      object.object_id,
      object.inspect[0, 500], # Neo4j limit is higher, but this is all we need
      labels.join(';')
    ])

    add_class(object.class)
    add_to_csv(:object_classes, [object.object_id, object.class.object_id])

    true
  end

  def add_class(klass)
    if add_object(klass)
      klass.included_modules.each do |mod|
        add_object(mod)

        add_to_csv(:class_modules, [klass.object_id, mod.object_id])
      end
    end
  end


  def import_object_space_neo4j_csvs(neo4j_db_path)
    system_or_fail "rm -rf #{neo4j_db_path}"

    puts "Importing"
    system_or_fail "./db/bin/neo4j-import \
      --delimiter TAB \
      --quote \"|\" \
      --into #{neo4j_db_path} \
      --nodes #{@csv_paths[:objects]} \
      --relationships:INSTANCE_VARIABLE #{@csv_paths[:instance_variables]} \
      --relationships:HAS_CLASS #{@csv_paths[:object_classes]} \
      --relationships:INCLUDES_MODULE #{@csv_paths[:class_modules]} \
      "
  end

  def system_or_fail(command)
    puts "Running command: #{command}".blue
    system(command) or fail "Unable to run: #{command}" # rubocop:disable Style/AndOr
  end

  private

  def add_to_csv(key, row)
    @csvs[key] << row
  end
end
