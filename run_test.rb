require './lib'

dumper = Neo4jObjectSpaceDumper.new

#dumper.setup_csvs

#puts 'Dumping...'
#dumper.object_space_to_neo4j_csvs

#require 'pry'
#binding.pry

puts 'Loading...'
dumper.import_object_space_neo4j_csvs('./db/data/graph.db')