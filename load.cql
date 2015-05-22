CREATE INDEX ON :Object(object_id);

MATCH n OPTIONAL MATCH n-[r]-() DELETE n, r;

LOAD CSV WITH HEADERS FROM 'file:///Users/brian/Projects/ruby_object_space_neo4j/objects.csv' AS line
CREATE (:Object {object_id: line.`object_id:ID`, inspect: line.inspect});

LOAD CSV WITH HEADERS FROM 'file:///Users/brian/Projects/ruby_object_space_neo4j/instance_variables.csv' AS line
MATCH
  (start:Object {object_id: line.`:START_ID`}),
  (end:Object {object_id: line.`:END_ID`})
CREATE start-[:INSTANCE_VARIABLE {variable: line.variable}]->end;

