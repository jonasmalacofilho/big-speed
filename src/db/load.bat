echo DROP TABLE IF EXISTS Raw; | sqlite3 "linkSpeed.db3"
echo CREATE TABLE Raw ( fromId INT, toId INT, day INT, time INT, dataType TEXT, dataValue REAL ); | sqlite3 "linkSpeed.db3"

for %f in ( "part-*" ) do type "%f" | neko load.n > "%f.csv" && echo .import "%f.csv" Raw | sqlite3 -separator , "linkSpeed.db3"
