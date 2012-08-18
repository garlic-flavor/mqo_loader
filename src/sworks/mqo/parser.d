/** Metasequoia モデルファイルとそれに類するフォーマットに利用できるパーサ。ランタイム版
 * Version:      0.0012(dmd2.060)
 * Date:         2012-Aug-17 00:12:50
 * Authors:      KUMA
 * License:      CC0
 */
module sworks.mqo.parser;

import std.algorithm, std.ascii, std.conv, std.range, std.stdio, std.string;
version(Windows) import std.windows.charset;
import sworks.mqo.misc;
import sworks.mqo.parser_core;

debug import sworks.compo.util.dump_members, std.stdio;

/*CCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCC*\
|*|                                CachedFile                                |*|
\*CCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCC*/
/**
 * std.stream.File をラップしようかと思ったけど、クソ遅いからやめた。$(BR)
 * std.stdio.File ってなんで日本語ファイル名に対応してないんじゃああああああ$(BR)
 */
class CachedFile : ICachedBuffer
{
	enum CACHE_SIZE = 255; /// キャッシュサイズ。

	string filename; /// 現在読み込んでいるファイル名
	File file; /// 本体。std.stdio.File。
	private byte[ CACHE_SIZE ] _cache; // 1次キャッシュ。
	private size_t cursor; // ファイル内での現在のオフセット。
	private size_t line_number; // ファイル内での現在の行数
	private size_t head, tail; // 1次キャシュのどの部分を使っているか。
	private Appender!(byte[]) _buffer; // 2次キャッシュ
	
	/**
	 * Params:
	 *   filename    = 対象とするファイル名
	 *   cursor      = 対象ファイル先頭からのオフセットを指定するとそこから読み込む。
	 *   line_number = 対象ファイル内での行数。cursor を指定した時は、ここも指定しないと行数がずれる。
	 *   close_flag  = true の時はファイルを開かずにおく。
	 */
	this( string filename, size_t cursor = 0, size_t line_number = 0, bool close_flag  = false )
	{
		this.filename = filename;
		this.cursor = cursor;
		this.line_number = line_number;
		if( !close_flag ) open( );
	}

	this( jstring filename, size_t cursor = 0, size_t line_number = 0, bool close_flag  = false )
	{
		this.filename = filename.c;
		this.cursor = cursor;
		this.line_number = line_number;
		if( !close_flag ) open( filename );
	}


	/// 対象ファイル先頭からのオフセット
	size_t position() @property const { return cursor; }
	/// 対象ファイル内での行数。
	size_t line() @property const { return line_number; }
	/// ファイルが開いているかどうか
	bool isOpen() @property const { return file.isOpen && head < tail; }
	/// ファイル終端に達しているかどうか
	bool eof() @property { return file.eof && tail <= head; }
	/// 複製を返す。返された CachedFile は開かれていない状態である。
	CachedFile dup() @property { return new CachedFile( filename, cursor, line_number, true ); }
	/// 1次キャッシュの中身を返す。
	const(byte)[] cache() @property { return _cache[ head .. tail ]; }
	/// 2次キャッシュの中身を返す。
	immutable(byte)[] buffer() @property { return _buffer.data.idup; }

	// 1次キャッシュを埋める。
	private bool refillCache()
	{
		tail = file.rawRead( _cache[ 0 .. $ - 1] ).length;
		_cache[ tail ] = 0;
		head = 0;
		return head < tail;
	}


	/// ファイルを開く。ファイルが既に開かれている場合はなにもしない。
	void open( )
	{
		if( !file.isOpen )
		{
			version(Windows)
			{
				auto fnz = filename.toMBSz;
				size_t i; for( i = 0 ; '\0' != fnz[i] ; i++ ){}
				file = File( cast(string)fnz[0 .. i] );
			}
			else file = File( filename );
			file.seek( cursor, SEEK_SET );
			_buffer.clear();
			refillCache();
		}
	}
	/// ditto
	void open( jstring filename )
	{
		if( !file.isOpen )
		{
			file = File( filename.c );
			file.seek( cursor, SEEK_SET );
			_buffer.clear();
			refillCache();
		}
	}


	/// ファイルを閉じる。
	void close()
	{
		file.close();
		_cache[] = 0;
		head = tail = 0;
		_buffer.clear;
		cursor = 0;
		line_number = 0;
	}

	/// 1次キャッシュの先頭の1バイトを読み取る。カーソルは進めない。
	byte peep() @property { return _cache[ head ]; }

	/**
	 * カーソルを進める。
	 * Params:
	 *   s = s個進める。
	 */
	byte discard( size_t s = 1 )
	{
		s = min( s, tail - head );
		for( size_t i = 0 ; i < s ; i++ ) line_number += MQ_NEWLINE[0] == _cache[ head + i ] ? 1 : 0;
		cursor += s;
		head += s;
		if( tail <= head ) refillCache();
		return _cache[ head ];
	}

	/**
	 * 現在の1次キャッシュの先頭から s バイトを2次キャッシュに溜め、その分のカーソルを進める。
	 * Params:
	 *   s = s 個溜める。
	 */
	byte push( size_t s = 1 )
	{
		for( size_t i = 0, k ; i < s ; )
		{
			k = min( s, tail - head );
			_buffer.put( _cache[ head .. head + k ] );
			i += k;
			discard( k );
		}
		return _cache[ head ];
	}

	/**
	 * カーソル位置からデータを読み取る。
	 * Param:
	 *   size = size バイト読み取る。
	 */
	immutable(byte)[] getBinary( size_t size )
	{
		push( size );
		auto ret = _buffer.data.idup;
		_buffer.clear;
		return ret;
	}

	/// 2次キャッシュをクリアする。
	void flush() { _buffer.clear; }
}

/*FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF*\
|*|                                   load                                   |*|
\*FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF*/
/**
 * ファイル -> D言語のオブジェクト
 * Params:
 *   filename  = ファイル名。
 *   OBJECT    = OBJECT.HEADER に、ヘッダ文字列をしこんでおく。
 * Returns:
 *   中身のばっちりつまった OBJECT型のインスタンス。
 * Throws:
 *   Exception パースに失敗した場合投げられる。
 */
OBJECT load( OBJECT )( string filename )
{
	try
	{
		auto cf = new CachedFile( filename );
		check_header( cf, OBJECT.HEADER );
		auto token = Token( cf );
		string vs; token.chomp( vs );
		OBJECT obj; token.chomp( obj );
		cf.close;
		static if( __traits( hasMember, OBJECT, "version_string" ) ) obj.version_string = vs;
		return obj;
	}
	catch( Throwable t ) throw new Exception( "an Error occured in " ~ filename.c ~ newline ~ t.toString );
}

