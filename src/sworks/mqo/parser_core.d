/** Metasequoia ファイルのパースに。ランタイム、コンパイルタイム、で共用できる部分
 * Version:      0.0013(dmd2.060)
 * Date:         2012-Aug-18 21:27:11
 * Authors:      KUMA
 * License:      CC0
 */
module sworks.mqo.parser_core;

import std.ascii, std.conv, std.exception, std.string;
import sworks.mqo.misc;

debug version = STRICT;


/*IIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIII*\
|*|                              ICachedBuffer                               |*|
\*IIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIII*/
/**
 * バッファの先頭一文字を読み取るけど、カーソルは進めない、peep 関数を実装する。
 */
interface ICachedBuffer
{
	bool isOpen() @property const;
	size_t position() @property const;
	size_t line() @property const;
	bool eof() @property const;
	byte peep() @property const;
	const(byte)[] cache() @property;
	immutable(byte)[] buffer() @property;

	void open();
	void close();
	byte discard( size_t s = 1 );
	byte push( size_t s = 1 );
	immutable(byte)[] getBinary( size_t size );
	void flush();

	ICachedBuffer dup() @property;
}

/// suger
bool startsWith( ICachedBuffer cb, const(byte)[] str )
{
	for( size_t i = 0 ; i < str.length ; i++, cb.discard ) if( cb.peep != str[i] ) return false;
	return true;
}

/// suger
void skipWhite( ICachedBuffer cb )
{
	for( ; !cb.eof && cb.peep.isWhite ; cb.discard ){ }
}

/// suger
bool startsWithKeyword( ICachedBuffer cb, const(byte)[] str )
{
	for( ; cb.peep.isWhite ; cb.discard ) if( cb.eof ) return false;
	for( size_t i = 0 ; i < str.length ; i++, cb.discard ) if( cb.peep != str[i] ) return false;
	return true;
}

string startsWithNumber( ICachedBuffer cb )
{
	for( ; cb.peep.isWhite ; cb.discard ) if( cb.eof ) return null;
	for( ; !cb.eof && ( cb.peep.isDigit || '.' == cb.peep || '_' == cb.peep ) ; cb.push ) { }
	string result = cb.buffer.c;
	cb.flush;
	return result;
}

/*IIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIII*\
|*|                                  INamed                                  |*|
\*IIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIII*/
interface INamed
{
	jstring name() @property const;
}

/*IIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIII*\
|*|                                 INamable                                 |*|
\*IIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIII*/
interface INamable : INamed
{
	void name( jstring ) @property;
}

/*IIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIII*\
|*|                                 ILength                                  |*|
\*IIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIII*/
interface ILength
{
	uint length() @property const;
	void length( uint ) @property;
}

/*IIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIII*\
|*|                                IOwnParser                                |*|
\*IIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIII*/
interface IOwnParser
{
	bool parser( ref Token );
}

/*IIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIII*\
|*|                              IHeaderChecker                              |*|
\*IIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIII*/
interface IHeaderChecker
{
	void checkHeader( ICachedBuffer );
}

/*SSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSS*\
|*|                                  Token                                   |*|
\*SSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSS*/
/**
 * ファイルの先頭1トークンの情報を格納している。$(BR)
 * popFront を呼び出してファイル内を巡回する。
 *
 * Bugs:
 * issue 8484 ( http://d.puremagic.com/issues/show_bug.cgi?id=8484 ) 回避の為(@2059) 構造体である必要がある。
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

	private ICachedBuffer file;

	TYPE type;
	private jstring _data;

	this( ICachedBuffer file )
	{
		this.file = file;
		type = TYPE.NONE;
		_data = null;
		popFront();
	}

	/// トークン → D言語の基本型
	string toString() const @property { return _data.c; }
	/// ditto
	jstring toJString() const @property
	{
		version(STRICT)
		{
			if( TYPE.JSTRING == type ) return _data;
			else throw new SyntaxException( file.line, toString()
			                              , "the cell is " ~ type.to!string ~ " type, but JString." );
		}
		else
		{
			if     ( TYPE.JSTRING == type || TYPE.KEYWORD == type || TYPE.INT == type || TYPE.FLOAT == type )
				return _data;
			else if( TYPE.LIST == type ) return " *** LIST CELL *** ".j;
			else if( TYPE.BINARY == type ) return " *** BINARY CELL *** ".j;
			else return " **** NONE CELL *** ".j;
		}
	}
	/// ditto
	string toKeyword() const @property
	{
		version(STRICT)
		{
			if( TYPE.KEYWORD == type ) return _data.c;
			else throw new SyntaxException( file.line, toString()
			                              , "the cell is " ~ type.to!string ~ " type, but Keyword." );
		}
		else
		{
			if     ( TYPE.JSTRING == type || TYPE.KEYWORD == type || TYPE.INT == type || TYPE.FLOAT == type )
				return _data.c;
			else if( TYPE.LIST == type ) return " *** LIST CELL *** ";
			else if( TYPE.BINARY == type ) return " *** BINARY CELL *** ";
			else return " **** NONE CELL *** ";
		}
	}
	/// ditto
	int toInt() const @property
	{
		version( STRICT )
		{
			if( TYPE.INT == type ) return _data.c.to!int;
			else throw new SyntaxException( file.line, toString()
			                              , "the cell is " ~ type.to!string ~ " type, but Int." );
		}
		else
		{
			if( TYPE.INT == type || TYPE.FLOAT == type ) return _data.c.to!int;
			else return 0;
		}
	}
	/// ditto
	float toFloat() const @property
	{
		version(STRICT)
		{
			if( TYPE.FLOAT == type ) return _data.c.to!float;
			else throw new SyntaxException( file.line, toString()
			                              , "the cell is " ~ type.to!string ~ " type, but Float." );
		}
		else
		{
			if( TYPE.INT == type || TYPE.FLOAT == type ) return _data.c.to!float;
			else return 0f;
		}
	}

	/// BVertex チャンク読み込み時に利用される。戻り値は ubyte[] なので、cast して使って下さい。
	immutable(ubyte)[] toBinary() const @property
	{
		version(STRICT)
		{
			if( TYPE.BINARY == type ) return cast(immutable(ubyte)[])_data;
			else throw new SyntaxException( file.line, toString()
			                              , "the cell is " ~ type.to!string ~ " type, but Float." );
		}
		else
		{
			if( TYPE.BINARY == type ) return cast(immutable(ubyte)[])_data;
			else return null;
		}
	}

	/// 次のトークンに処理を移す。
	void popFront()
	{
		_data = null;
		ubyte h;
		for(  h = file.peep ; h.isWhite || '=' == h || ',' == h ; h = file.discard() ) { }

		if     ( 0 == h ) { type = TYPE.NONE; }
		else if( '}' == h || ')' == h ){ file.discard(); type = TYPE.LIST_END; }
		else if( '{' == h || '(' == h ){ file.discard(); type = TYPE.LIST; }
		else if( '"' == h )
		{
			for( h = file.discard ; !file.eof && '"' != h ; h = file.push() ) {};
			type = TYPE.JSTRING;
			_data = file.buffer;
			if( '"' == h ) file.discard();
		}
		else if( '[' == h )
		{
			for( h = file.discard ; !file.eof && ']' != h ; h = file.push() ) { }
			auto num = file.buffer.c.strip.to!size_t;
			if( ']' == file.peep ) file.discard();
			if( '\n' == file.peep ) file.discard();
			else if( '\r' == file.peep && '\n' == file.discard ) file.discard;
			type = TYPE.BINARY;
			_data = file.getBinary( num );
		}
		else
		{
			bool isFloat = false;
			for( h = file.push ; !file.eof && !h.isWhite && '=' != h && ',' != h && '{' != h && '(' != h && ')' != h
			                                             && '}' != h ; h = file.push ) isFloat |= ( '.' == h );
			_data = file.buffer;
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
	 *   SyntaxException 予期せぬ事態の場合に投げられる。
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
	 * というメンバを定義する。$(BR)
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
				// .mks のベクタチャンク内の curve と .mkm のベクタチャンク内の curve の型が違うので、
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
					enforce( t.length * T.sizeof == bin.length, "the length of a binary data is not correct." );
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
					version( STRICT ) enforce( TYPE.NONE != type, "more dates are needed for " ~ OBJECT.stringof );
					static if( !__traits( compiles, __traits( getMember, t, one ).offsetof ) ){}
					else chomp( __traits( getMember, t, one ) );
				}
			}
			else static if( is( OBJECT == class ) )
			{
				if( null is t )
				{
					t = new OBJECT();
					static if( __traits( hasMember, OBJECT, "length" ) )
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
				static if( __traits( hasMember, OBJECT, "parser" ) )
				{
					if( TYPE.NONE != type && t.parser( this ) && TYPE.NONE != type )
					{
						version( STRICT ) enforce( save != file.position, key ~ " is not expected as keyword." );
						return chomp( t );
					}
					return;
				}
				if( save == file.position )
				{
					version( STRICT ) enforce( 0, "\"" ~ key ~ "\" is not collect as a keyword." );
					popFront;
				}

			}
			else version( STRICT ) enforce( 0, OBJECT.stringof ~ " is not supported data type." );
		}
		catch( SyntaxException se ) throw se;
		catch( Exception e )
		{
			throw new SyntaxException( file.line, _data.c, e.toString );
		}
	}

}

/*FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF*\
|*|                               check_header                               |*|
\*FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF*/
/**
 * ヘッダの読み込み。
 * Params:
 *   reg = <del>ヘッダにヒットする正規表現。captures[1] にヴァージョン文字列が入るようにする。</del>( after ver0.0011 )$(BR)
 *         
 * Return:
 *   <del>ヴァージョン文字列</del>
 */
/*
void check_header( ICachedBuffer cf, string reg )
{
	auto version_field = cast(string)cf.cache;
	if( version_field.startsWith( reg ) ) cf.discard( reg.length );
	else throw new Exception( "file header is not correct." );
}
*/
