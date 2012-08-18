/**
 * Version:      0.0012(dmd2.060)
 * Date:         2012-Aug-17 00:12:50
 * Authors:      KUMA
 * License:      CC0
*/
module sworks.compo.sdl.iconv;

public import sworks.compo.sdl.util;

private
{
	import derelict.util.loader;
	import derelict.util.system;

	static if(Derelict_OS_Windows)
		enum libNames = "libiconv-2.dll";
	else
		static assert( 0, "need to implement iconv libName for this operationg system." );
}

alias void* iconv_t;

extern(C)
{
	alias nothrow iconv_t function( const(char)*, const(char)* ) da_iconv_open;
	alias nothrow size_t function( iconv_t, void**, size_t*, void**, size_t* ) da_iconv;
	alias nothrow int function( iconv_t ) da_iconv_close;

	alias nothrow int* function() da_errno;
}

__gshared
{
da_iconv_open iconv_open;
da_iconv iconv;
da_iconv_close iconv_close;
}

class IConvLoader : SharedLibLoader
{
public:
	this(){ super(libNames); }
protected:
	override void loadSymbols()
	{
		bindFunc(cast(void**)&iconv_open, "libiconv_open" );
		bindFunc(cast(void**)&iconv, "libiconv" );
		bindFunc(cast(void**)&iconv_close, "libiconv_close" );
	}
}

__gshared IConvLoader IConv;

shared static this()
{
	IConv = new IConvLoader();
}

shared static ~this()
{
	IConv.unload();
}

SDLExtInitDel getIConvInitializer()
{
	return
	{
		IConv.load();
		return { };
	};
}

enum ICONV_INVALID_DESCRIPTOR = cast(iconv_t)(-1);
enum ICONV_RESULT_ERROR = cast(size_t)(-1);

import std.array;
class IConvConverter( string TCODE, string FCODE, TCHAR = char, size_t BUFFER_SIZE = 1024)
{
	private iconv_t _cd = ICONV_INVALID_DESCRIPTOR;

	this()
	{
		_cd = iconv_open( TCODE.ptr, FCODE.ptr );
		enforce( ICONV_INVALID_DESCRIPTOR != _cd
		       , "IConvConverter(" ~ FCODE ~ "->" ~ TCODE ~ ") : failure in iconv_open" );
	}

	~this(){ if( ICONV_INVALID_DESCRIPTOR != _cd ) iconv_close( _cd ); }

	immutable(TCHAR)[] opCall(T)( in const(T)[] src )
	{
		assert( ICONV_INVALID_DESCRIPTOR != _cd );
		auto result = appender!(immutable(TCHAR)[])();

		auto srcptr = src.ptr;
		auto srcleft = src.length * T.sizeof;

		auto dst = new TCHAR[ BUFFER_SIZE ];
		TCHAR* dstptr;
		size_t dstleft;

		size_t r;
		for( ; 0 < srcleft ; )
		{
			dstptr = dst.ptr;
			dstleft = dst.length * TCHAR.sizeof;
			iconv( _cd, cast(void**)&srcptr, &srcleft, cast(void**)&dstptr, &dstleft );
			enforce( dst.length != dstleft, "IConvConverter(" ~ FCODE ~ "->" ~ TCODE ~ ") : conversion failed." );
			result.put( dst[ 0 .. $ - dstleft ] );
		}
		return result.data;
	}
}

debug(iconv):
import std.stdio;
import std.file : write, read;
void main()
{
	IConv.load();

	scope auto converter = new IConvConverter!( "UTF-8", "SHIFT-JIS", char, 64 )();
	write( "uni-d-san.mqo", converter( cast(char[])read( "d-san.mqo" ) ) );
//	writeln( converter( "日本語でおｋ" ) );

}
