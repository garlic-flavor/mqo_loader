/** Metasequoia ファイルの実行時パーサ
 */
/**
 * Bugs:
 *   dmd2.060現在、CTFE のバグ(http://d.puremagic.com/issues/show_bug.cgi?id=6498) により実装不可能
 */
module sworks.mqo.ct_parser;

import std.algorithm, std.ascii, std.conv, std.string;
import sworks.mqo.misc;
import sworks.mqo.parser_core;

/*CCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCC*\
|*|                               CachedBuffer                               |*|
\*CCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCC*/
class CachedBuffer : ICachedBuffer
{
	private jstring _buffer;
	private size_t cursor;
	private size_t line_number;
	private size_t save;

	this( jstring b, size_t c = 0, size_t ln = 0 )
	{
		this._buffer = b;
		save = cursor = c;
		line_number = ln;
	}

	bool isOpen() @property const { return 0 < _buffer.length; }
	size_t position() @property const { return cursor; }
	size_t line() @property const { return line_number; }
	bool eof() @property const { return _buffer.length <= cursor; }
	byte peep() @property const { return cursor < _buffer.length ? _buffer[cursor] : '\0'; }
	const(byte)[] cache() @property { return _buffer[ cursor .. $ ]; }
	immutable(byte)[] buffer() @property { return _buffer[ save .. cursor ]; }

	void open(){ }
	void close(){ _buffer = null; }
	byte discard( size_t s = 1 )
	{
		auto r = push( s );
		save = cursor;
		return r;
	}

	byte push( size_t s = 1 )
	{
		s = min( cursor + s, _buffer.length );
		for( ; cursor < s ; cursor++ ) if( MQ_NEWLINE[0] == _buffer[cursor] ) line_number++;
		return peep;
	}

	immutable(byte)[] getBinary( size_t size )
	{
		save = cursor;
		push( size );
		auto result = _buffer[ save .. cursor ];
		save = cursor;
		return result;
	}

	void flush() { save = cursor; }

	ICachedBuffer dup() @property { return new CachedBuffer( _buffer, cursor, line_number ); }
}

OBJECT load(OBJECT, string filename )()
{
	try
	{
		auto cf = new CachedBuffer( import(filename).j );
		check_header( cf, OBJECT.HEADER );
		auto token = Token(cf);
		string vs; token.chomp( vs );

		OBJECT obj; token.chomp( obj );
		cf.close;
		static if( __traits( hasMember, OBJECT, "version_string" ) ) obj.version_string = vs;

		return obj;
	}
	catch( SyntaxException t ){ throw new Exception( "error occured in " ~ filename ~ newline ~ t.toString ); }
}
