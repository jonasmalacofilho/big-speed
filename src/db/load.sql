.restore linkSpeed.db3

ANALYZE;
VACUUM;

DROP TABLE IF EXISTS Link;
CREATE TABLE Link ( id INTEGER PRIMARY KEY AUTOINCREMENT, fromId INT, toId INT );
DROP TABLE IF EXISTS TimeInterval;
CREATE TABLE TimeInterval ( id INTEGER PRIMARY KEY AUTOINCREMENT, day INT, time INT );
DROP TABLE IF EXISTS LinkSpeed;
CREATE TABLE LinkSpeed( lid INT, tid INT, val REAL, wgt REAL, PRIMARY KEY ( tid, lid ) );

DROP INDEX IF EXISTS RawIndex_ind_0;
CREATE INDEX RawIndex_ind_0 ON Raw ( fromId, toId, day, time, dataType );

INSERT INTO Link
	SELECT DISTINCT
		NULL, fromId, toId
	FROM Raw;
SELECT COUNT( 1 ) FROM Link;

INSERT INTO TimeInterval
	SELECT DISTINCT
		NULL, day, time
	FROM Raw;
SELECT COUNT( 1 ) FROM TimeInterval;

ANALYZE;

INSERT INTO LinkSpeed
-- EXPLAIN QUERY PLAN
	SELECT
		Link.id
		, TimeInterval.id
		, SUM( v.dataValue )
		, SUM( w.dataValue )
	FROM Link
	JOIN TimeInterval
	JOIN Raw v ON Link.fromId=v.fromId AND Link.toId=v.toId AND TimeInterval.day=v.day AND TimeInterval.time=v.time AND v.dataType='1'
	JOIN Raw w ON Link.fromId=w.fromId AND Link.toId=w.toId AND TimeInterval.day=w.day AND TimeInterval.time=w.time AND w.dataType='2'
	GROUP BY Link.id, TimeInterval.id;

.backup linkSpeed.db3

PRAGMA journal_mode=off;
DROP TABLE Raw;
PRAGMA page_size=4096;
ANALYZE;
VACUUM;

.backup linkSpeed2.db3
