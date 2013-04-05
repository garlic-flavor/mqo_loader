/**
 * Version:      0.0014(dmd2.062)
 * Date:         2013-Apr-06 01:08:29
 * Authors:      KUMA
 * License:      CC0
*/
module sworks.compo.util.dump_members;

import std.array, std.ascii, std.conv, std.range, std.traits;
import sworks.compo.util.strutil;
debug import std.stdio;

Appender!string add( Appender!string buf, string msg )
{
	buf.put( msg );
	return buf;
}

Appender!string ln( Appender!string buf, string msg )
{
	buf.put( msg );
	buf.put( newline );
	return buf;
}

// ???
Appender!string tabAdd( uint TAB_WIDTH )( Appender!string buf, uint indent, string msg )
{
	buf.put( newline );
	buf.put( ' '.repeat.take( indent * TAB_WIDTH ) );
	buf.put( msg );
	return buf;
}


Appender!string dummy_call(uint TAB_SIZE)(Appender!string buf, string msg ){ buf.put( msg ); return buf; }

/// Dのオブジェクト -> メンバ名とその内容を表す文字列 デバグ用
string dump_members( THIS )( THIS t, uint max_indent = 12, uint max_array = 64, uint indent = 0 )
{
	enum TAB_WIDTH = 4;
	auto result = appender!string();

	string call(U)( U u ){ return dump_members( u, max_indent, max_array, indent ); }
	Appender!string tab( string msg ){ return tabAdd!TAB_WIDTH( result, indent, msg ); }

	
	static if     ( is( THIS == class ) )
	{
		if( null !is t )
		{
			tab( THIS.stringof );
			tab( "{" );
			indent++;
			static if( __traits( hasMember, t, "dump" ) )
			{
				tab( t.dump( max_indent, max_array, indent ) );
			}
			else
			{
				if( indent < max_indent )
				{
					foreach( one ; __traits( derivedMembers, THIS ) )
					{
						static if( __traits( compiles, __traits( getMember, t, one ).offsetof ) )
						{
							tab( one ).add( " = " ).add( call( __traits( getMember, t, one ) ) );
						}
					}
				}
				else tab( " ... " );
			}
			indent--;
			tab( "}" );
		}
		else result.put( "null" );
	}
	else static if( is( THIS == interface ) || isCallable!THIS )
	{
		static if( __traits( hasMember, t, "dump" ) )
		{
			indent++;
			tab( t.dump( max_indent, max_array, indent ) );
			indent--;
		}
		else
		{
			if( null !is t ) tab( THIS.stringof );
			else result.put( "null" );
		}
	}
	else static if( is( THIS == struct ) )
	{
		tab( THIS.stringof );
		tab( "{" );
		indent++;
		static if( __traits( hasMember, t, "dump" ) )
		{
			tab( t.dump( max_indent, max_array, indent ) );
		}
		else
		{
			if( indent < max_indent )
			{
				foreach( one ; __traits( derivedMembers, THIS ) )
				{
					static if( __traits( compiles, __traits( getMember, t, one ).offsetof ) )
					{
						tab( one ).add( " = " ).add( call( __traits( getMember, t, one ) ) );
					}
				}
			}
			else tab( " ... " );
		}
		indent--;
		tab( "}" );
	}
	else static if( isSomeString!THIS )
	{
		result.put( t.to!string );
	}
	else static if( is( THIS : const(jchar)[] ) )
	{
		result.put( t.c );
	}
	else static if( is( THIS T : T[] ) )
	{
		result.put( " [ " );
		indent++;
		if( indent < max_indent )
		{
			foreach( counter, one ; t )
			{
				if( max_array < counter ) { result.put( " ... " ); break; }
				result.add( call( one ) ).add( " " );
			}
		}
		else result.put( " ... " );
		indent--;
		result.put( "] " );
	}
	else static if( __traits( isAssociativeArray, THIS ) )
	{
		result.put( " [ " );
		indent++;
		if( indent < max_indent )
		{
			uint counter = 0;
			foreach( key, one ; t )
			{
				if( max_array < counter ) { result.put( " ... " ); break; }
				result.add( call( key ) ).add( " : " ).add( call( one ) ).add( ", " );
				counter++;
			}
		}
		else result.put( " ... " );
		indent--;
		result.put( " ] " );
	}
	else static if( is( THIS T : T* ) )
	{
		if( null !is t ) return call(*t);
		else return "null";
	}
	else result.put( t.to!string );
	return result.data;
}

debug(dump_members):
import std.stdio;

class Test
{
	int x;
	double[] d;
	string msg;
	Test t;
	Test[string] at;

	string hoge( string t ) { return "hello world"; }
}

void main()
{
	auto t = new Test;
	t.at[ "hello" ] = new Test;
	t.at[ "world" ] = new Test;
	writeln( t.dump_members );
}
