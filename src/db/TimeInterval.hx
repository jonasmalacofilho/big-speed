package db;

import sys.db.Types;

class TimeInterval extends sys.db.Object {
	public var id:SId;
	public var weekday:SInt;
	public var time:SInt;

	public function new( _weekday, _time ) {
		super();
		weekday = _weekday;
		time = _time;
		insert();
	}

	public static function get( _weekday:Int, _time:Int ) {
		var ti = manager.select( $weekday==_weekday && $time==_time );
		if ( ti == null )
			ti = new TimeInterval( _weekday, _time );
		return ti;
	}
}
