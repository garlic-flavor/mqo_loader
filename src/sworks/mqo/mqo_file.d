module sworks.mqo.mqo_file;

import sworks.compo.util.cached_buffer;

/*EEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEE*\
|*|                                MQ_NEWLINE                                |*|
\*EEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEE*/
/// Metasequoia では改行コードは MS式で固定(?)
enum MQ_NEWLINE = "\r\n";

/*CCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCC*\
|*|                               MQOException                               |*|
\*CCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCC*/
/**
 * parse 時に投げられる。
 * version(STRICT) では、よりたくさん例外を投げる。
 * debug コンパイルでは STRICT がデフォルト。
 */
class MQOException : Throwable
{
	string message;

	/**
	 * Params:
	 *   line_num  = 問題が起きた対象ファイル内での行数。CachedFile が保持している。
	 *   cell_cont = 問題の箇所
	 *   msg       = ここにスタックトレース情報が入っていることを期待している。
	 */
	this( string filename, size_t line_num, const(char)[] cell_cont, string msg
	    , string source_filename = __FILE__, int line = __LINE__ )
	{
		message = newline ~ filename ~ " を解析中に問題が発生しました。" ~ newline ~ line_num.to!string
		          ~ " 行目 : 問題の箇所\"" ~ cell_cont.idup ~ "\"" ~ newline ~ msg ~ ~newline;
		if( __ctfe ) super( message, source_filename, line );
		else super( "MQOException", source_filename, line );
	}

	override string toString() { return message; }
	string stack_trace() @property { return super.toString; }
}

//
class MQOMessage : Throwable
{
	string message;

	this( string msg )
	{
		if( __ctfe ) super( msg );
		else super( "MQOMessage" );
		this.message = msg
	}
	override string toString() @property { return message; }
	string stack_trace() @property { return super.toString; }
}

//
class TMQOFile
{
	alias ICache = TICache!char;
	private ICache _cache;

	this( string f, size_t cache_size = 1024 )
	{
		auto _file = 
		this._cache = new TCachedBuffer!char( 
	}
}