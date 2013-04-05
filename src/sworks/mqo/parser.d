/** Metasequoia ファイルのパースに。
 * Version:      0.0014(dmd2.062)
 * Date:         2013-Apr-06 01:08:29
 * Authors:      KUMA
 * License:      CC0
 */
module sworks.mqo.parser;

import std.ascii, std.conv, std.exception, std.string, std.stdio, std.range, std.algorithm;
import sworks.compo.util.class_switch;
import sworks.compo.util.cached_buffer;
import sworks.compo.util.sequential_file;
import sworks.compo.util.dregex;
//version( Windows ) import sworks.compo.win32.sjis; // <del>std.stdio.File が日本語ファイル名未対応の為</del>dmd2.062にて対応
import sworks.mqo.misc;
debug import std.stdio;

/*EEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEE*\
|*|                                MQ_NEWLINE                                |*|
\*EEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEE*/
/// Metasequoia では改行コードは MS式で固定(?)
enum MQ_NEWLINE = "\r\n";

/*CCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCC*\
|*|                             SyntaxException                              |*|
\*CCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCC*/
debug version = STRICT;
/**
 * version(STRICT) では、よりたくさん例外を投げる。
 * debug コンパイルでは STRICT がデフォルト。
 */
class SyntaxException : Exception
{
	this( string msg, string filename = __FILE__, int line = __LINE__ ) { super( msg, filename, line ); }
}

/// $(D_PARAM cond) が偽の時、SyntaxExceptionを投げる。
T enforceSyntax(T)( T cond, in MqoFile file, lazy string msg, string filename = __FILE__, int line = __LINE__ )
{
	if( cast(bool)cond ) return cond;
	throw new SyntaxException( (cast(MqoFile)file).msg(msg), filename, line );
}

/*CCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCC*\
|*|                                 MqoFile                                  |*|
\*CCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCC*/
/// Metasequoia ファイルを格納する。
class MqoFile : TICache!jchar
{
	private const dchar LINE_TAIL;
	private TICache!jchar _cache;
	private string _filename;
	private size_t _position;
	private File _file;

	/// $(D_PARAM filename) は Metasequoia ファイル名
	this( string filename )
	{
		_filename = filename;
		_position = 0;
		_file = File( filename, "rb" );
		_cache = new TCachedBuffer!jchar( r=>_file.rawRead(r).length, s=>_file.seek( s, SEEK_CUR ), ()=>_file.close );
		LINE_TAIL = _cache.peekBetter.decide_line_tail;
	}

	/// $(D_PARM filecont) は Metasequoia ファイルの中身。文字コードは SHIFT-JIS
	this( jstring filecont )
	{
		_filename = "JSTRING";
		_position = 0;
		_cache = new TWholeCache!jchar( filecont );
		LINE_TAIL = _cache.peekBetter.decide_line_tail;
	}

	/// .mqo ファイル名。$(BR)
	/// this( jstring $(D_PARAM filecont) ) でインスタンス化された場合、値は $(D_STRING JSTRING)
	string filename() @property const { return _filename; }
	/// キャッシュサイズ。
	size_t size() @property const { return _cache.size; }
	/// キャッシュの残り。
	const(jchar)[] rest() @property const { return _cache.rest; }
	/// ファイル終端に達しているかどうか
	bool eof() @property const { return _cache.eof; }
	/// ファイル内でのオフセット
	size_t position() @property const { return _position; }
	/// キャッシュの先頭一文字
	jchar front() @property { return _cache.front; }
	/// カーソルを $(D_PARAM s) 字進める。
	jchar popFront( size_t s = 1 )
	{
		_position += s;
		return _cache.popFront( s );
	}
	/// $(D_PARAM size) byteチラ見する。カーソルは進めない。キャッシュサイズより沢山 peek できない。
	const(jchar)[] peek( size_t size ){ return _cache.peek( size ); }
	/// メモリコピーをなるべく減らすヴァージョン
	const(jchar)[] peekBetter(){ return _cache.peekBetter(); }

	/// ファイルを閉じられる場合は閉じる。
	void close() { _cache.close(); }

	/// キャッシュ先頭から $(D_PARAM size) byte 読み込み、その分のカーソルを進める。
	jstring getBinary( size_t size )
	{
		auto result = _cache.getBinary( new jchar[ size ] );
		_position += result.length;
		return assumeUnique( result );
	}
	/// ditto
	jchar[] getBinary( jchar[] buf ) { return _cache.getBinary( buf ); }

	/// 一時記憶領域にキャッシュ先頭の $(D_PARAM s) 字を記憶し、その分のカーソルを進める。
	jchar push( size_t s = 1 ){ _position += s; return _cache.push(s); }
	/// 一時記憶領域に $(D_PARAM jc) を記憶し、カーソルを1進める。
	jchar push( jchar jc ){ return _cache.push( jc ); }
	/// 一時記憶領域を内容を返す。
	const(jchar)[] stack() @property { return _cache.stack; }
	/// 一時記憶領域の内容をクリアする。
	void flush(){ _cache.flush; }

	//
	debug Benchmark getBenchmark() { return _cache.getBenchmark; }

	/// 現在のキャッシュの内容で例外用のメッセージを作る。
	string msg( string msg )
	{
		ubyte[] pre;
		class_switch( _cache
			, ( TWholeCache!jchar c )
			{
				pre = cast(ubyte[])c.cache[ 0 .. _position ];
			}
			, ( TCachedBuffer!jchar c )
			{
				if( 0 < _position )
				{
					_file.rewind();
					pre = new ubyte[ _position ];
					_file.rawRead( pre );
					_file.close();
				}
			}
		);
		auto pre_line =  cast(char[])pre[ pre.retro.find( LINE_TAIL ).count!"true" .. $ ];
		return  [ "SyntaxException : in ", _filename, newline, (pre.count(LINE_TAIL)+1).to!string, ":", pre_line, stack.c, newline, msg ].joiner.to!string;
	}
}

/*IIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIII*\
|*|                                  INamed                                  |*|
\*IIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIII*/
/// クラスで実装し、パーサ生成に利用する。
interface INamed
{
	jstring name() @property const;
}

/*IIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIII*\
|*|                                 INamable                                 |*|
\*IIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIII*/
/// ditto
interface INamable : INamed
{
	void name( jstring ) @property;
}

/*IIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIII*\
|*|                                 ILength                                  |*|
\*IIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIII*/
/// ditto
interface ILength
{
	uint length() @property const;
	void length( uint ) @property;
}

/*IIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIII*\
|*|                                IOwnParser                                |*|
\*IIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIII*/
/// ditto
interface IOwnParser
{
	bool parser( ref Token );
}

/*SSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSS*\
|*|                                  Token                                   |*|
\*SSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSS*/
/**
 * ファイルの先頭1トークンの情報を格納している。$(BR)
 * popFront を呼び出してファイル内を巡回する。
 *
 * Bugs:
 * issue 8484($(LINK http://d.puremagic.com/issues/show_bug.cgi?id=8484)) 回避の為(@2059) 構造体である必要がある。
 */
struct Token
{
	/// トークンのタイプ
	enum TYPE
	{
		NONE,
		FILE,
		LIST,
		LIST_END,
		JSTRING,
		KEYWORD,
		INT,
		FLOAT,
		BINARY,
	}

	private MqoFile file;

	TYPE type;
	private const(jchar)[] _data;

	///
	this( MqoFile file )
	{
		this.file = file;
		type = TYPE.NONE;
		_data = null;
		popFront();
	}

	/// トークン → D言語の基本型
	// .mks のベクタチャンク内の curve と .mkm のベクタチャンク内の curve の型が違うので、version(STRICT)でも type を調べない。
	string toString() const @property { return (cast(const(char)[])_data).idup; }
	/// ditto
	jstring toJString() const @property
	{
		version(STRICT) enforceSyntax( TYPE.JSTRING == type, file, "the cell " ~ _data.c ~ " is " ~ type.to!string ~ " type, but JString." );
		if     ( TYPE.JSTRING == type || TYPE.KEYWORD == type || TYPE.INT == type || TYPE.FLOAT == type ) return _data.idup;
		else if( TYPE.LIST == type ) return " *** LIST CELL *** ".j;
		else if( TYPE.BINARY == type ) return " *** BINARY CELL *** ".j;
		else return " **** NONE CELL *** ".j;
	}
	/// ditto
	string toKeyword() const @property
	{
		version(STRICT) enforceSyntax( TYPE.KEYWORD == type, file, "the cell " ~ _data.c ~ " is " ~ type.to!string ~ " type, but Keyword." );
		if     ( TYPE.JSTRING == type || TYPE.KEYWORD == type || TYPE.INT == type || TYPE.FLOAT == type ) return (cast(const(char)[])_data).idup;
		else if( TYPE.LIST == type ) return " *** LIST CELL *** ";
		else if( TYPE.BINARY == type ) return " *** BINARY CELL *** ";
		else return " **** NONE CELL *** ";
	}
	/// ditto
	int toInt() const @property
	{
		version( STRICT ) enforceSyntax( TYPE.INT == type, file, "the cell " ~ _data.c ~ " is " ~ type.to!string ~ " type, but Int." );
		if( TYPE.INT == type || TYPE.FLOAT == type ) return _data.c.to!int;
		else return 0;
	}
	/// ditto
	float toFloat() const @property
	{
		version(STRICT) enforceSyntax( TYPE.FLOAT == type, file, "the cell " ~ _data.c ~ " is " ~ type.to!string ~ " type, but Float." );
		if( TYPE.INT == type || TYPE.FLOAT == type ) return _data.c.to!float;
		else return 0f;
	}

	/// BVertex チャンク読み込み時に利用される。戻り値は ubyte[] なので、cast して使って下さい。
	immutable(ubyte)[] toBinary() const @property
	{
		version(STRICT) enforceSyntax( TYPE.BINARY == type, file, "the cell " ~ _data.c ~ " is " ~ type.to!string ~ " type, but Float." );
		if( TYPE.BINARY == type ) return cast(immutable(ubyte)[])_data;
		else return null;
	}

	/// 次のトークンに処理を移す。
	void popFront()
	{
		_data = null;
		ubyte h;
		for(  h = file.front ; h.isWhite || '=' == h || ',' == h ; h = file.popFront ) { }

		if     ( 0 == h ) { type = TYPE.NONE; }
		else if( '}' == h || ')' == h ){ file.popFront; type = TYPE.LIST_END; }
		else if( '{' == h || '(' == h ){ file.popFront; type = TYPE.LIST; }
		else if( '"' == h )
		{
			for( h = file.popFront ; !file.eof && '"' != h ; h = file.push() ) {};
			type = TYPE.JSTRING;
			_data = file.stack;
			if( '"' == h ) file.popFront;
		}
		else if( '[' == h )
		{
			for( h = file.popFront ; !file.eof && ']' != h ; h = file.push() ) { }
			auto num = file.toString.strip.to!uint;
			if( ']' == file.front ) file.popFront;
			if( '\n' == file.front ) file.popFront;
			else if( '\r' == file.front && '\n' == file.popFront ) file.popFront;
			type = TYPE.BINARY;
			_data = file.getBinary( num );
		}
		else
		{
			bool isFloat = false;
			for( h = file.push ; !file.eof && !h.isWhite && '=' != h && ',' != h && '{' != h && '(' != h && ')' != h
			                                             && '}' != h ; h = file.push ) isFloat |= ( '.' == h );
			_data = file.stack;
			if     ( 0 == _data.length ) type = TYPE.NONE;
			else if( isAlpha( cast(char)_data[0] ) ) type = TYPE.KEYWORD;
			else if( isFloat ) type = TYPE.FLOAT;
			else type = TYPE.INT;
		}
		file.flush;
	}

/*
	void popFrontList()
	{
		for( ; TYPE.LIST_END != type || TYPE.NONE != type ; popFront ){ }
		if( TYPE.LIST_END == type ) popFront;
	}
*/

	/**
	 * 現在のトークンから OBJECT を切り出す。
	 * Params:
	 *   t = ここに切り出された値が格納される。
	 * Throws:
	 *   SyntaxException が予期せぬ事態に投げられる。
	 * Bugs:
	 *   OBJECT は引数無しのコンストラクタを持っている必要がある。
	 *
	 * 処理は再帰的に行なわれる。
	 * <ol>
	 *   <li> OBJECT が D言語の基本型の場合はそのまま std.conv に渡す。</li>
	 *   <li> OBJECT が静的配列の場合は、丁度配列長分だけ、chomp を再帰呼び出しする。</li>
	 *   <li> OBJECT が動的配列の場合は、次のトークンが配列長を示し、その後に配列の内容が続いているとする。</li>
	 *   <li> OBJECT が構造体の場合は、ソースコード上でメンバの定義順に chomp を再帰呼び出しする。</li>
	 *   <li> OBJECT がクラスの場合は、キーワードにマッチするメンバで chomp を再帰呼び出しする。</li>
	 * </ol>
	 *
	 * メンバに特殊な書式をパースする必要がある場合、$(BR)
	 * IOwnParser インターフェイスを実装して下さい。$(BR)
	 * クラスの他のメンバ名と、token.toKeyword がヒットしなかった場合、parser が呼ばれる。$(BR)
	 * parser で処理した場合は内部でその分 token を進めて下さい。$(BR)
	 * 続けて同じインスタンスに対して chomp を呼び出す場合は parser から true を返し、$(BR)
	 * そのインスタンスに対する処理を終える場合は false を返して下さい。$(BR)
	 */
	void chomp(OBJECT)( ref OBJECT t )
	{
		try
		{
			version( STRICT ) enforce( TYPE.NONE != type, "SEGV but more " ~ TYPE.stringof ~ " data is needed." );
			if( TYPE.NONE == type || TYPE.LIST_END == type ) return;

			// リストの時は中身を調べる
			if( TYPE.LIST == type )
			{
				popFront;
				chomp( t );
				version( STRICT ) enforce( TYPE.LIST_END == type );
				popFront;
				return;
			}

			// 基本型
			static if     ( is( OBJECT : int ) )
			{
				t = toInt;
				popFront;
			}
			else static if( is( OBJECT : float ) )
			{
				t = toFloat;
				popFront;
			}
			else static if( is( OBJECT : jstring ) )
			{
				t = toJString;
				popFront;
			}
			else static if( is( OBJECT : string ) )
			{
				t = toString;
				popFront;
			}

			// 複合型
			else static if( is( OBJECT T : T[N], size_t N ) )
			{
				foreach( ref one ; t ) chomp( one );
			}
			else static if( is( OBJECT TT : TT[jstring] ) && is( TT : INamable ) )
			{
				jstring name; chomp( name );
				TT obj; chomp( obj );
				obj.name = name;
				t[name] = obj;
			}
			else static if( is( OBJECT T : T[jstring] ) && is( T : INamed ) )
			{
				T obj; chomp( obj );
				t[obj.name] = obj;
			}
			else static if( is( OBJECT T : T[] ) )
			{
				if( 0 == t.length )
				{
					int l; chomp( l );
					version( STRICT ) enforce( 0 < l );
					t = new T[ l ];
					return chomp(t);
				}

				if( TYPE.BINARY == type )
				{
					auto bin = toBinary;
					enforceSyntax( t.length * T.sizeof == bin.length, file, "the length of a binary data is not correct." );
					version( LittleEndian ) t[] = (cast(T*)(bin.ptr))[ 0 .. t.length ];
					version( BigEndian )
					{
						for( size_t i = 0 ; i < t.length ; i ++ )
							t[i] = bin[ i * T.sizeof .. (i+1) * T.sizeof ].littleEndianToNative!T;
					}
					popFront;
				}
				else
				{
					foreach( ref one ; t ) chomp( one );
				}
			}
			else static if( is( OBJECT == struct ) )
			{
				static if( __traits( hasMember, OBJECT, "parser" ) ) return t.parser( this );
				foreach( one ; __traits( derivedMembers, OBJECT ) )
				{
					version( STRICT ) enforceSyntax( TYPE.NONE != type, file, "more dates are needed for " ~ OBJECT.stringof );
					static if( !__traits( compiles, __traits( getMember, t, one ).offsetof ) ){}
					else chomp( __traits( getMember, t, one ) );
				}
			}
			else static if( is( OBJECT == class ) )
			{
				if( null is t )
				{
					t = new OBJECT();
					static if( is( OBJECT : ILength ) )
					{
						if( 0 == t.length && 0 < toInt )
						{
							int l; chomp( l );
							t.length = l;
							enforce( TYPE.NONE != type );
						}
					}
					return chomp( t );
				}

				auto save = file.position;
				auto key = toString;

				if( 0 == "eof".icmp( key ) ) { file.close; type = TYPE.NONE; return; }
				foreach( one ; __traits( derivedMembers, OBJECT ) )
				{
					static if( !__traits( compiles, __traits( getMember, t, one ).offsetof ) ) { }
					else if( 0 == one.icmp( key ) || 0 == one.icmp( key ~ "_data" ) )
					{
						popFront;
						chomp( __traits( getMember, t, one ) );
						if( TYPE.NONE != type ) return chomp( t );
						else return;
					}
				}
				static if( is( OBJECT : IOwnParser ) )
				{
					if( TYPE.NONE != type && t.parser( this ) && TYPE.NONE != type )
					{
						version( STRICT ) enforceSyntax( save != file.position, file, key ~ " is not expected as a keyword." );
						return chomp( t );
					}
					return;
				}
				if( save == file.position )
				{
					version( STRICT ) enforceSyntax( false, file, "\"" ~ key ~ "\" is not collect as a keyword." );
					popFront;
				}

			}
			else version( STRICT ) enforceSyntax( false, file, OBJECT.stringof ~ " is not a supported data type." );
		}
		catch( SyntaxException se ) throw se;
		catch( Exception e ) enforceSyntax( false, file, e.msg );
	}

}

/*FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF*\
|*|                               check_header                               |*|
\*FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF*/
/**
 * ヘッダの読み込み。
 * Params:
 *   reg = ヘッダ文字列。ヴァージョン文字列が始まる直前まで。
 *   <del>reg = ヘッダにヒットする正規表現。captures[1] にヴァージョン文字列が入るようにする。</del>( after ver0.0011 )$(BR)
 */
string checkHeader( MqoFile file, string reg )
{
/*
	auto version_field = file.peekBetter.c;
writeln( version_field.startsWith( "Metasequoia Document\nFormat Text Ver" ) );
//	enforceSyntax( 0 < version_field.startsWith( reg ), file, "file header is no t correct" );
//	file.popFront( reg.length );
//	return Token( file ).toString;
return "";
*/
/*
	auto m = (cast(string)file.peekBetter).match( reg );
	enforceSyntax( !m.empty, file, "file header is not correct." );
	auto c = m.captures;
	c.popFront;
	enforceSyntax( !c.empty, file, "file version string is not detected." );
	auto v = c.front.idup;
	file.popFront( m.pre().length + m.hit().length );
	return v;
//*/
	auto regex = dirtyRegex!jchar( reg.j );
	auto range = new PeekRange!jchar( file );
	auto mr = range.beginWith( regex );
	enforceSyntax( !mr.empty, file, "file version string is not detected." );
	return mr.captures[0].c;
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
	auto cf = new MqoFile( filename );
	auto vs = cf.checkHeader( OBJECT.HEADER );
	OBJECT obj; Token(cf).chomp( obj );
	cf.close;
	static if( __traits( hasMember, OBJECT, "version_string" ) ) obj.version_string = vs;
	return obj;
}

/** CTFE version is under construction
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
*/
