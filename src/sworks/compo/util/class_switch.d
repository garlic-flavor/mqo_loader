/**
 * Version:      0.0014(dmd2.062)
 * Date:         2013-Apr-06 01:08:29
 * Authors:      KUMA
 * License:      CC0
*/
module sworks.compo.util.class_switch;

//==============================================================================
//
void class_switch( T, D ... )( T key, D prog )
{
	if( key is null ) return;
	foreach( one ; prog )
	{
		static if( ( ( is( typeof( one ) U == delegate ) && is( U F == function ) )
		         || is( typeof( *one ) F == function ) ) && F.length == 1
		         && ( is( F[0] P == class ) || is(F[0] P == interface ) ) )
		{
			auto p = cast( P )key;
			if( p is null ) continue;
			one( p );
			break;
		}
		else static assert( "the prog must be a Tuple of pointers of a delegate or a function");
	}
}
