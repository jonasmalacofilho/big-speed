import vehjo.LazyLambda;
import vehjo.macro.Error;

class LinkResult {

	var nIntervals: Int;
	var dt: Float;
	var val: Array<Float>;
	var wgt: Array<Float>;
	var speed( get, never ): Array<Float>;

	public function new( nIntervals: Int ) {
		this.nIntervals = nIntervals;
		dt = 24.*3600./nIntervals;
		val = LazyLambda.array( LazyLambda.map( LazyLambda.lazy( 0...nIntervals ), 0. ) );
		wgt = val.copy();
	}

	// t must be seconds from day start
	public function add( t: Float, val: Float, wgt: Float ) {
		var i = Std.int( t/dt );
		vehjo.macro.Debug.assertIf( i >= nIntervals, i );
		if ( i >= nIntervals )
			i -= nIntervals;
		this.val[i] += val;
		this.wgt[i] += wgt;
	}

	public function merge( x: LinkResult ) {
		Error.throwIf( nIntervals != x.nIntervals );
		for ( i in 0...nIntervals ) {
			val[i] += x.val[i];
			wgt[i] += x.wgt[i];
		}
	}

	public function iterator(): Iterator<LinkResultPartial> {
		return LazyLambda.map( wgt, new LinkResult.LinkResultPartial( dt*$i, val[$i], $x ) ).iterator();
	}

	function get_speed(): Array<Float> {
		return LazyLambda.array( LazyLambda.map( wgt, $x > 0 ? val[$i]/$x : $x ) );
	}

}

class LinkResultPartial {
	public var t( default, null ): Float;
	public var val( default, null ): Float;
	public var wgt( default, null ): Float;
	public function new( t, val, wgt ) {
		this.t = t;
		this.val = val;
		this.wgt = wgt;
	}
}
