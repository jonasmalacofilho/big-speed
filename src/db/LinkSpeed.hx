package db;

import sys.db.Types;

@:id( lid, tiid )
class LinkSpeed extends sys.db.Object {
	@:relation( lid ) public var link:Link;
	@:relation( tiid ) public var timeInterval:TimeInterval;
	public var value:SFloat;
	public var weight:SFloat;

	public function new( _link, _timeInterval, _value, _weight ) {
		super();
		link = _link;
		timeInterval = _timeInterval;
		value = _value;
		weight = _weight;
		insert();
	}

	public static function absorbValue( _link:Link, _timeInterval:TimeInterval, _value:Float ) {
		var x = manager.select( $link==_link && $timeInterval==_timeInterval );
		if ( x != null ) {
			x.value += _value;
			x.update();
		}
		else
			x = new LinkSpeed( _link, _timeInterval, _value, 0. );
		return x;
	}

	public static function absorbWeight( _link:Link, _timeInterval:TimeInterval, _weight:Float ) {
		var x = manager.select( $link==_link && $timeInterval==_timeInterval );
		if ( x != null ) {
			x.weight += _weight;
			x.update();
		}
		else
			x = new LinkSpeed( _link, _timeInterval, 0., _weight );
		return x;
	}

}
