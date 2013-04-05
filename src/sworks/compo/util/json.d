/**
 * Version:      0.0001(dmd2.062)
 * Date:         2013-Mar-27 03:45:29
 * Authors:      KUMA
 * License:      CC0
*/
module sworks.compo.util.json;

public import std.json;

JSONValue json( string val )
{
	JSONValue jval;
	jval.str = val;
	jval.type = JSON_TYPE.STRING;
	return jval;
}

JSONValue json( int val )
{
	JSONValue jval;
	jval.integer = val;
	jval.type = JSON_TYPE.INTEGER;
	return jval;
}

JSONValue json( uint val )
{
	JSONValue jval;
	jval.uinteger = val;
	jval.type = JSON_TYPE.UINTEGER;
	return jval;
}

JSONValue json( float val )
{
	JSONValue jval;
	jval.floating = val;
	jval.type = JSON_TYPE.FLOAT;
	return jval;
}

JSONValue json( JSONValue[string] val )
{
	JSONValue jval;
	jval.object = val;
	jval.type = JSON_TYPE.OBJECT;
	return jval;
}

JSONValue json( JSONValue[] val )
{
	JSONValue jval;
	jval.array = val;
	jval.type = JSON_TYPE.ARRAY;
	return jval;
}

JSONValue json( bool val )
{
	JSONValue jval;
	jval.type = val ? JSON_TYPE.TRUE : JSON_TYPE.FALSE;
	return jval;
}

JSONValue json()
{
	JSONValue jval;
	jval.type = JSON_TYPE.NULL;
	return jval;
}

JSONValue json( int[] val )
{
	auto cont = new JSONValue[ val.length ];
	foreach( i, one ; val ) cont[i] = one.json;
	return cont.json;
}

JSONValue json( uint[] val )
{
	auto cont = new JSONValue[ val.length ];
	foreach( i, one ; val ) cont[i] = one.json;
	return cont.json;
}

JSONValue json( float[] val )
{
	auto cont = new JSONValue[ val.length ];
	foreach( i, one ; val ) cont[i] = one.json;
	return cont.json;
}

JSONValue json( string[] val )
{
	auto cont = new JSONValue[ val.length ];
	foreach( i, one ; val ) cont[i] = one.json;
	return cont.json;
}
