import vehjo.ds.RjTree;
import vehjo.macro.Debug;
import vehjo.macro.Error;
import vehjo.Vector;
import LinkResult;
import emmekit.Scenario;
using vehjo.LazyLambda;

/* TODOs:
 - input from gps points (and not segments)
 - properly deal with seg.dir.mod() == 0 (maybe even small values > 0)
 ? better probDist function (or proper calibration of the current function)
 ? better probDir function (taking into account gps and link segment lengths)
 */

class NetworkSpeed {

	// object state
	var emmeScen: Scenario; // referenc emme scenario (network)
	var linkRes: Map<Int,LinkResult>; // results per link

	// settings
	// user-defined settings
	var minDt: Float; // s
	var maxDt: Float; // s
	var maxTanDistFactor: Float; // factor of max( GPSSegment::length, SLink::length )
	var maxOrtDistFactor: Float; // factor of max( GPSSegment::length, SLink::length )
	var minSpeed: Float; // m/s
	var maxSpeed: Float; // m/s
	var minWeekday: Int; // [0-6], 0==Sunday
	var maxWeekday: Int; // [0-6], 0==Sunday
	var minTime: Float; // s
	var maxTime: Float; // s
	var specMinDxDy: Float; // coordinate units
	// auto-computed settings
	var nTimeIntervals: Int; // number of intervals by witch days are split

	function new( netInPath, shpInPath, fileInPath, outPath, outTable, keyDescr, minDt, maxDt, maxTanDistFactor, maxOrtDistFactor, minSpeed, maxSpeed, minWeekday, maxWeekday, minTime, maxTime, specMinDxDy, ?limit=-1 ) {

		// user-defined settings
		this.minDt = minDt;
		this.maxDt = maxDt;
		this.maxTanDistFactor = maxTanDistFactor;
		this.maxOrtDistFactor = maxOrtDistFactor;
		this.minSpeed = minSpeed;
		this.maxSpeed = maxSpeed;
		this.minWeekday = minWeekday;
		this.maxWeekday = maxWeekday;
		this.minTime = minTime;
		this.maxTime = maxTime;

		// reading the emme scenario
		Sys.println( 'Reading the emme network' );
		Error.throwIf( !sys.FileSystem.exists( netInPath ), netInPath + ' not found' );
		Error.throwIf( !sys.FileSystem.exists( shpInPath ), shpInPath + ' not found' );
		emmeScen = new Scenario();
		emmeScen.distance = function ( ax, ay, bx, by ) return dist( new Vector( ax, ay ), new Vector( bx, by ) );
		emmeScen.eff_read( sys.io.File.read( netInPath, false ) ).close();
		emmeScen.eff_read( sys.io.File.read( shpInPath, false ) ).close();

		// minimum bounding box dimensions
		Sys.println( 'Converting the minimum dx and dy from meters to coordinate units' );
		// average x and y
		var xmed = 0.;
		var ymed = 0.;
		for ( node in emmeScen.node_iterator() ) {
			xmed += node.xi;
			ymed += node.yi;
		}
		xmed /= emmeScen.node_count;
		ymed /= emmeScen.node_count;
		this.specMinDxDy = Math.max( emmeScen.rev_distance_dx( xmed, ymed, specMinDxDy, 0. ), emmeScen.rev_distance_dy( xmed, ymed, specMinDxDy, 0. ) );

		// preparing storage for the results
		Sys.println( 'Preparing storage for the results' );
		// 15' intervals
		nTimeIntervals = 24*4;
		// alloc
		linkRes = new Map();
		for ( lk in emmeScen.link_iterator() )
			linkRes.set( lk.id, new LinkResult( nTimeIntervals ) );

		// data input
		Sys.println( 'Reading data' );
		var fileInp = sys.io.File.read( fileInPath, false );
		var csvInp = new vehjo.format.csv.Reader( fileInp );
		csvInp.readRecord(); // skip header
		var row = 0; // read rows counter
		var sw = new vehjo.StopWatch();
		var pre: GPSPoint = null;
		while ( true ) try {
			var r = csvInp.readRecord();
			var cur = GPSPoint.fromStringArray( r );
			if ( ++row % 1000 == 0 ) // debug and status information printed each 1000 read rows
				Sys.print( '\r${Std.int( sw.partial() )}s: now on row ${Std.int( row*1e-3 )}k' );
			if ( limit >= 0 && row > limit )
				throw new haxe.io.Eof();
			if ( pre != null && cur.veh != pre.veh )
				pre = null;
			if ( pre != null ) {
				absorb( new GPSSegment( pre.time, cur.time, pre.x, cur.x, pre.y, cur.y ) );
			}
			else {
				Debug.assert( cur.veh );
			}
			pre = cur;
		}
		catch ( e: haxe.io.Eof ) {
			break;
		}
		fileInp.close();
		Sys.println( '\r${Std.int( sw.partial() )}s: now on row ${Std.int( row*1e-3 )}k' );

		// results output
		Sys.println( 'Outputing results to SQLite database' );
		var now = Date.now();
		// connection
		var dbOut = sys.db.Sqlite.open( outPath );
		dbOut.request( "PRAGMA cache_size=-1000" );
		dbOut.startTransaction();
		// key
		dbOut.request( "CREATE TABLE IF NOT EXISTS \"${outTable}_key\" ( key INTEGER PRIMARY KEY AUTOINCREMENT, desc TEXT, localDate TEXT, timestamp REAL )" );
		dbOut.request( "INSERT INTO \"${outTable}_key\" ( desc, localDate, timestamp ) VALUES ( '${keyDescr}', '${now}', ${now.getTime()/1000.} )" );
		var key = dbOut.request( "SELECT max( key ) FROM \"${outTable}_key\"" ).getIntResult( 0 );
		dbOut.commit();
		// data
		dbOut.request( "CREATE TABLE IF NOT EXISTS \"${outTable}_data\" ( key INT, fromNode INT, toNode INT, t REAL, val REAL, wgt REAL )" );
		dbOut.request( "CREATE INDEX IF NOT EXISTS \"${outTable}_data_ind_key\" ON \"${outTable}_data\" ( key, fromNode, toNode, t )" );
		dbOut.request( "CREATE INDEX IF NOT EXISTS \"${outTable}_data_ind_no_key\" ON \"${outTable}_data\" ( fromNode, toNode, t )" );
		for ( lk in emmeScen.link_iterator() ) {
			var lkRes = linkRes.get( lk.id );
			for ( rt in lkRes )
				if ( rt.wgt > 0. )
					dbOut.request( "INSERT INTO \"${outTable}_data\" VALUES ( ${key}, ${lk.fr.i}, ${lk.to.i}, ${rt.t}, ${rt.val}, ${rt.wgt} )" );
		}
		dbOut.commit();
		dbOut.close();

	}

	// fitness due to object distance (probDist)
	// given dist and its maximum alowed value, probDist is computed as
	//                      1 - dist/maxDist
	// where:
	//   0 < maxDist < +INF
	//   0 <= dist <= maxDist
	function probDist( dist: Float, maxDist: Float ) {
		Error.throwIf( maxDist <= 0 );
		Error.throwIf( dist < 0 );
		return Math.max( 1 - dist/maxDist, 0. );
	}

	// given two midpoint vectors, computes the fitness due to object distance (probDist)
	// the result considers both ortogonal and tangential distances (reference vector is refDir)
	// with different weights (or maximum alowed distances)
	function probPos( a: Vector, b: Vector, maxLength: Float, refDir: Vector ) {
		var dist = b.sub( a ); // distance between both midpoint vectors
		return probDist( dist.proj( refDir ).mod(), maxTanDistFactor*maxLength )*
			probDist( dist.proj( refDir.ort() ).mod(), maxOrtDistFactor*maxLength );
	}

	// given two vectors, computes the finess due to the angle between them
	// given theta>pi/2 the resulting probability quickly goes to zero
	// both a and b must have module > 0
	function probDir( a: Vector, b: Vector ) {
		var modA = a.mod();
		var modB = b.mod();
		Error.throwIf( modA == 0. );
		Error.throwIf( modB == 0. );
		return Math.pow( a.dotProduct( b )/( modA*modB )*.5 + .5, 2. );
	}

	// work function
	// receives a GPSSegment x and aborsbs its speed into the network
	function absorb( x: GPSSegment ): Void {

			var dt = x.t1 - x.t0; // time interval of the gps segment (in seconds)

			if ( !between( dt, minDt, maxDt ) || dt <= 0. ) // dt user defined filter + avoid division by zero exception in speed computation
				return;

			var d0 = Date.fromTime( 1000.*x.t0 ); // initial time date
			if ( !between( d0.getDay(), minWeekday, maxWeekday ) ) // weekday filter
				return;
			var s0 = getSecondsOfDay( d0 ); // seconds from 00:00 of the same day
			if ( !between( s0, minTime, maxTime ) ) // time filter (is seconds from day start)
				return;

			// from/to/direction computation
			var from = new Vector( x.x0, x.y0 ); // from vector
			var to = new Vector( x.x1, x.y1 ); // to vector
			var dir = to.sub( from );
			if ( dir.mod() == 0. ) // this can cause problems with probDir
				return; // for now, later this will be handled properly (this dt should be inclued in the previous ou next gps segment)

			// speed computation
			var speed = dist( from, to )/dt; // speed computed from the current gps segment (in m/s)
			Debug.assertIf( !between( speed, minSpeed, maxSpeed ), speed*3.6 );
			if ( !between( speed, minSpeed, maxSpeed ) ) // gps segment speed filter
				return;

			// minimum bounding box computation
			var min = new Vector( Math.min( x.x0, x.x1 ), Math.min( x.y0, x.y1 ) );
			var max = new Vector( Math.max( x.x0, x.x1 ), Math.max( x.y0, x.y1 ) );
			var delta = max.sub( min );

			// bounding box adjustment
			// adds 1/8*max( dx, dy ) to both dimensions
			// considers a minimum dx and dy
			var maxDxDy = Math.max( delta.x, delta.y );
			var delta2 = new Vector( Math.max( delta.x + maxDxDy/4, specMinDxDy ), Math.max( delta.y + maxDxDy/4, specMinDxDy ) );
			var min2 = min.sub( delta2.sub( delta ).scale( .5 ) ); // adjust min to the new bouding box

			// midpoint
			var pos = min.sum( delta.scale( .5 ) );

			// RTree querying and result computation based on fitness estimates
			for ( y in emmeScen.link_search_rectangle( min2.x, min2.y, min2.x + delta2.x, min2.y + delta2.y ) ) {
				var p = 0.; // initial probability is zero

				var prePt = null;
				for ( pt in y.full_shape() ) {
					if ( prePt != null && pt.sub( prePt ).mod() > 0 ) { // for each segment with mod()>0
						var linkSeg = new SLink( prePt, pt );

						// fitness by objects positions, using link segment as reference (ort/tan)
						var pPos = probPos( pos, linkSeg.pos, Math.max( dir.mod(), linkSeg.dir.mod() ), linkSeg.dir );
						Debug.assertIf( Math.isNaN( pPos ) || !Math.isFinite( pPos ) || pPos > 1 || pPos < 0, untyped [ pPos, pos, linkSeg.pos, Math.max( dir.mod(), linkSeg.dir.mod() ), linkSeg.dir ] );
						// Error.throwIf( Math.isNaN( pPos ) || !Math.isFinite( pPos ) || pPos > 1 || pPos < 0 );

						// fitness by objects directions
						var pDir = probDir( dir, linkSeg.dir );
						Debug.assertIf( Math.isNaN( pDir ) || !Math.isFinite( pDir ) || pDir > 1 || pDir < 0, untyped [ pDir, dir, linkSeg.dir ] );
						// Error.throwIf( Math.isNaN( pDir ) || !Math.isFinite( pDir ) || pDir > 1 || pDir < 0 );

						// global fitness
						if ( pPos*pDir > p )
							p = pPos*pDir;
					}
					prePt = pt;
				}

				// val,wgt assignment
				if ( p > 0 )
					linkRes.get( y.id ).add( s0, speed*p, p );

			}

	}

	static inline function getSecondsOfDay( x: Date ): Float {
		return 3600.*x.getHours() + 60.*x.getMinutes() + x.getSeconds();
	}

	static inline function between<A: Float>( x: A, l: A, u: A ): Bool {
		return x >= l && x <= u;
	}

	/**
		Static helper functions
	**/

	static inline function dist( a: Vector, b: Vector ): Float {
		return vehjo.MathExtension.earth_distance_haversine( a.y, a.x, b.y, b.x );
	}

	/**
		Entry point
	**/

	static function main() {
		new NetworkSpeed(
			'network.out',
			'shapes.out',
			'gps_data.csv',
			'speed.db3',
			'speed',
			'unnamed test',
			25., // min dt
			35., // max dt
			1., // max tan dist factor
			1., // max ort dist factor
			0., // min speed
			90./3.6, // max speed
			1, // min weekday
			5, // max weekday
			5.*3600, // min time (05h00'00'')
			11.*3600 - 1., // max time (10h59'59'')
			30. // min search bounding box dx or dy, in m
		);
	}

}
