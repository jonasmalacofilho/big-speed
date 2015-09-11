import emmekit.Link;
import emmekit.Scenario;
import vehjo.Vector;
import vehjo.macro.Debug;
import vehjo.macro.Error;
using vehjo.LazyLambda;

class NetworkSpeedMapper {

	static var stdin = Sys.stdin();
	static var stderr = Sys.stderr();
	static var stdout = Sys.stdout();

	// Reference network (Emme)
	var emmeScen: Scenario;

	// User defined filters
	// Time interval between GPS points
	var minDt: Float; // s
	var maxDt: Float; // s
	// GPS segment speed
	var minSpeed: Float; // m/s
	var maxSpeed: Float; // m/s
	// Weekday
	var minWeekday: Int; // [0-6], 0==Sunday
	var maxWeekday: Int; // [0-6], 0==Sunday
	// Day time
	var minTime: Float; // s
	var maxTime: Float; // s

	// User defined tuning settings
	// Bounding box edge minimum size
	var specMinDxDy: Float; // coordinate units
	// Midpoint maximum distance factors
	var maxTanDistFactor: Float; // factor of max( GPSSegment::length, SLink::length )
	var maxOrtDistFactor: Float; // factor of max( GPSSegment::length, SLink::length )

	// Auto computed settings
	var nTimeIntervals: Int; // number of intervals by witch days are split
	var dtTimeIntervals: Float; // interval length is seconds

	// Auxiliary output settings
	var verbose: Bool;

	function new(
		netInPath, shpInPath,
		minDt: Float, maxDt: Float,
		maxTanDistFactor: Float, maxOrtDistFactor: Float,
		minSpeed: Float, maxSpeed: Float,
		minWeekday: Int, maxWeekday: Int,
		minTime: Float, maxTime: Float,
		specMinDxDy: Float,
		?verbose=false
	) {

		// User defined filters
		this.minDt = minDt;
		this.maxDt = maxDt;
		this.minSpeed = minSpeed;
		this.maxSpeed = maxSpeed;
		this.minWeekday = minWeekday;
		this.maxWeekday = maxWeekday;
		this.minTime = minTime;
		this.maxTime = maxTime;

		// Auto computed settings
		nTimeIntervals = 24*4; // 15' time intervals
		dtTimeIntervals = 24.*3600./nTimeIntervals;

		// Network input
		stderr.writeString( 'Reading the emme network\n' );
		Error.throwIf( !sys.FileSystem.exists( netInPath ), netInPath + ' not found' );
		Error.throwIf( !sys.FileSystem.exists( shpInPath ), shpInPath + ' not found' );
		emmeScen = new Scenario();
		emmeScen.distance = function ( ax, ay, bx, by ) return 1e-3*dist( new Vector( ax, ay ), new Vector( bx, by ) );
		emmeScen.eff_read( sys.io.File.read( netInPath, false ) ).close();
		emmeScen.eff_read( sys.io.File.read( shpInPath, false ) ).close();

		// Midpoint maximum distance factors
		this.maxTanDistFactor = maxTanDistFactor;
		this.maxOrtDistFactor = maxOrtDistFactor;

		// Bounding box edge minimum size
		stderr.writeString( 'Converting the minimum dx and dy from meters to coordinate units\n' );
		var xmed = 0.; // average x
		var ymed = 0.; //     and y
		for ( node in emmeScen.node_iterator() ) {
			xmed += node.xi;
			ymed += node.yi;
		}
		xmed /= emmeScen.node_count;
		ymed /= emmeScen.node_count;
		this.specMinDxDy = Math.max( emmeScen.rev_distance_dx( xmed, ymed, 1e-3*specMinDxDy, 0. ), emmeScen.rev_distance_dy( xmed, ymed, 1e-3*specMinDxDy, 0. ) );

		// Data input
		stderr.writeString( 'Reading data\n' );
		var row = 0; // read rows counter
		var sw = new vehjo.StopWatch();
		while ( true ) try {
			var r = stdin.readLine().split( ',' );
			var cur = GPSSegment.fromStringArray( r );

			if ( ++row % 1000 == 0 && verbose ) // debug and status information printed each 1000 read rows
				stderr.writeString( '\r${Std.int( sw.partial() )}s: now on row ${Std.int( row/1000 )}k' );

			absorb( cur );
		}
		catch ( e: haxe.io.Eof ) {
			break;
		}
		catch ( e: Dynamic ) {
			stderr.writeString( 'Error near row ' + Std.int( row/1000 ) + 'k: ' + e + '\n' );
			stderr.writeString( haxe.CallStack.toString( haxe.CallStack.exceptionStack() ) + '\n' );
		}
		stderr.writeString( '\r${Std.int( sw.partial() )}s: now on row ${Std.int( row/1000 )}k\n' );

	}

	// Actual mapper
	// Receives a GPSSegment x and aborsbs its speed into the network
	function absorb( x: GPSSegment ): Void {

			var dt = x.t1 - x.t0; // time interval of the gps segment (in seconds)

			// Filtering by time interval between GPS points
			if ( !between( dt, minDt, maxDt ) || dt <= 0. ) { // dt user defined filter + avoid division by zero exception in speed computation
				Debug.assertTrue( dt >= 0. ); // reports if a negative dt was found
				return;
			}

			// Filtering by weekday and daytime
			var d0 = Date.fromTime( 1000.*x.t0 ); // initial time date
			var wd0 = d0.getDay(); // current weekday
			if ( !between( wd0, minWeekday, maxWeekday ) ) // weekday filter
				return;
			var s0 = getSecondsOfDay( d0 ); // seconds from 00:00 of the same day
			if ( !between( s0, minTime, maxTime ) ) // time filter (is seconds from day start)
				return;

			// Computing from/to/direction vectors
			var from = new Vector( x.x0, x.y0 ); // from vector
			var to = new Vector( x.x1, x.y1 ); // to vector
			var dir = to.sub( from );
			if ( dir.mod() == 0. ) { // this can cause problems with probDir
				Debug.assertIf( dir.mod() == 0., [ from, to, dir ] );
				return; // should be handled in the preprocessing fase (included in the next segment)
			}

			// Computing speed
			var speed = dist( from, to )/dt; // speed computed from the current gps segment (in m/s)
			// Filter by speed
			if ( !between( speed, minSpeed, maxSpeed ) ) { // gps segment speed filter
				Debug.assertIf( !between( speed, minSpeed, maxSpeed ), speed*3.6 );
				return;
			}

			// Minimum bounding box computation from GPS segment
			var min = new Vector( Math.min( x.x0, x.x1 ), Math.min( x.y0, x.y1 ) );
			var max = new Vector( Math.max( x.x0, x.x1 ), Math.max( x.y0, x.y1 ) );
			var delta = max.sub( min );

			// Bounding box adjustment
			// Adds 1/2*max( dx, dy ) to the smallest dimension and 1/4*max( dx, dy ) to the largest one
			// Also garanties that both dx and dy are at least their minimum values
			var maxDxDy = Math.max( delta.x, delta.y );
			var delta2 = new Vector( Math.max( delta.x + ( delta.x < maxDxDy ? maxDxDy/2 : maxDxDy/4 ), specMinDxDy ), Math.max( delta.y + ( delta.y < maxDxDy ? maxDxDy/2 : maxDxDy/4 ), specMinDxDy ) );
			var min2 = min.sub( delta2.sub( delta ).scale( .5 ) ); // adjusts min to the new bouding box

			// Midpoint
			var pos = from.sum( dir.scale( .5 ) );

			// RTree querying and result computation based on fitness estimates
			// Each link found will receive p*speed as value and p as weight, thus computing the average speed weighted by p (the fitness estimate)
			// The fitness estimate p for each link is the maximum one of each of its segments (that result for its inflection points)
			for ( link in emmeScen.link_search_rectangle( min2.x, min2.y, min2.x + delta2.x, min2.y + delta2.y ) ) {
				// Initial probability is zero
				var p = 0.;

				var prePt = null;
				for ( pt in link.full_shape() ) {
					if ( prePt != null ) { // for each link segment
						var linkSeg = new SLink( prePt, pt );
						if ( linkSeg.dir.mod() > 0 ) { // removing those with mod() == 0

							// Partial fitness estimate using object positions
							// Reference is link segment
							// Considerd ortogonal and tangential midpoint distances
							// Check "probDist functions.xlsx" to visualize the function behaviour with suplied (hardcoded) parameters
							var pPosTan = probPos( pos, linkSeg.pos, .5*1.2*( dir.mod() + linkSeg.dir.mod() ), linkSeg.dir, 4. );
							var pPosOrt = probPos( pos, linkSeg.pos, .5*1.0*( dir.mod() + linkSeg.dir.mod() ), linkSeg.dir.ort(), 1.5 );
							var pPos = pPosTan*pPosOrt;
							Debug.assertIf( Math.isNaN( pPos ) || !Math.isFinite( pPos ) || pPos > 1 || pPos < 0, untyped [ pPos, pos, linkSeg.pos, Math.max( dir.mod(), linkSeg.dir.mod() ), linkSeg.dir ] );

							// Partial fitness estimate using object directions
							var pDir = probDir( dir, linkSeg.dir );
							Debug.assertIf( Math.isNaN( pDir ) || !Math.isFinite( pDir ) || pDir > 1 || pDir < 0, untyped [ pDir, dir, linkSeg.dir ] );

							// Global fitness estimate
							if ( pPos*pDir > p )
								p = pPos*pDir; // improved estimate

						}
					}
					prePt = pt;
				}

				// val,wgt assignment
				if ( p > 0 )
					save( link, wd0, s0, speed*p, p );

			}

	}

	/**
		Helper methods
	**/

	// Generic fitness estimate due to object distance (probDist)
	// Given dist and its maximum alowed value, probDist is computed as
	//                      1 - ( dist/maxDist )^exp
	// where:
	//   0 < maxDist < +INF
	//   0 <= dist <= maxDist
	inline function probDist( dist: Float, maxDist: Float, exp: Float ) {
		Error.throwIf( maxDist <= 0 );
		Error.throwIf( dist < 0 );
		return Math.max( 1. - Math.pow( dist/maxDist, exp ), 0. );
	}

	// Partial fitness estimate due to object midpoint ortogonal and tangential distances
	// Given two midpoint vectors, computes the fitness due to object distance (probDist)
	// Reference vector is refDir
	inline function probPos( a: Vector, b: Vector, maxLength: Float, refDir: Vector, exp: Float ) {
		var dist = b.sub( a ); // distance between both midpoint vectors
		return probDist( dist.proj( refDir ).mod(), maxTanDistFactor*maxLength, exp );
	}

	// Partial fitness estimate due to the angle between two objects
	// Given theta>pi/2 the resulting probability quickly goes to zero
	// Also, both a and b must have module > 0
	// Check "probDir functions.xlsx" to visualize the function behaviour
	inline function probDir( a: Vector, b: Vector ) {
		var modA = a.mod();
		var modB = b.mod();
		Error.throwIf( modA <= 0. );
		Error.throwIf( modB <= 0. );
		return Math.pow( a.dotProduct( b )/( modA*modB )*.5 + .5, 2. );
	}

	// Output for Hadoop mapper
	// Outputs two lines, one for val and one for wgt
	// Key is from-to-weekday-daytime
	// Value is either val or wgt
	// Weekday is in the 0-6 range, 0 being Sunday
	function save( lk: Link, wd0: Int, s0: Float, val: Float, wgt: Float ): Void {
		// Rounding down s0 to the closest dtTimeIntervals integer multiplier
		var i = Std.int( s0/dtTimeIntervals );
		var s0_ = dtTimeIntervals*i;
		vehjo.macro.Debug.assertIf( i >= nTimeIntervals, i );
		// Output
		stdout.writeString( 'DoubleValueSum:${lk.fr.i}-${lk.to.i}-$wd0-$s0_-val\t$val\nDoubleValueSum:${lk.fr.i}-${lk.to.i}-$wd0-$s0_-wgt\t$wgt\n' );
	}

	/**
		Helper (static) functions
	**/

	// Seconds elapsed from day start (localtime)
	static inline function getSecondsOfDay( x: Date ): Float {
		return 3600.*x.getHours() + 60.*x.getMinutes() + x.getSeconds();
	}

	// Between, lower and upper bound included
	static inline function between<A: Float>( x: A, l: A, u: A ): Bool {
		return x >= l && x <= u;
	}

	// Distance between two points in the geoid, in meters
	// Receives two vectors with coordinates in decimal degrees
	static inline function dist( a: Vector, b: Vector ): Float {
		return vehjo.MathExtension.earth_distance_haversine( a.y, a.x, b.y, b.x );
	}

	static function customTrace( v: Dynamic, ?p: haxe.PosInfos ) {
		stderr.writeString( '${p.fileName}: ${p.lineNumber}: $v\n' );
	}

	/**
		Entry point
	**/

	static function main() {
		haxe.Log.trace = customTrace;
		if ( Sys.args().length == 1 && Sys.args()[0] == '--version' ) {
			Sys.println( FossilTools.getCheckoutUuid() );
		}
		else {
			var emmeNetPath = Sys.getEnv( 'EMME_NET' );
			Error.throwIf( emmeNetPath == null );
			var emmeNetShpPath = Sys.getEnv( 'EMME_SHP' );
			Error.throwIf( emmeNetShpPath == null );
			new NetworkSpeedMapper(
				emmeNetPath,
				emmeNetShpPath,
				25., // min dt
				35., // max dt
				1., // max tan dist factor
				1., // max ort dist factor
				0., // min speed
				90./3.6, // max speed
				0, // min weekday
				6, // max weekday
				0.*3600, // min time (00h00'00'')
				24.*3600 - 1., // max time (23h59'59'')
				30. // min search bounding box dx or dy, in m
			);
		}
	}

}
