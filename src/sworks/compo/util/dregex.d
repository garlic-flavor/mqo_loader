/** regular expression. short-hand, slow, dirty but CTFE compatible!
 * Version:      0.0014(dmd2.062)
 * Date:         2013-Apr-06 01:08:29
 * Authors:      KUMA
 * License:      CC0
 */
module sworks.compo.util.dregex;

import std.ascii, std.exception, std.conv, std.traits;
import sworks.compo.util.strutil;
import sworks.compo.util.cached_buffer;

/*
 * Bugs:
 *   \p{ ... } is not implemented yet.
 *   std.array.Appender doesn't work in some case when CTFE.
 *
 * Compatibility:
 *   aim the compatibility with http://dlang.org/phobos/std_regex.html
 *
 *   Expression             | Support
 *   --------------------------------------------------
 *     any character        | o
 *     except [{|*+?()^$    |
 *   --------------------------------------------------
 *     .                    | o
 *   --------------------------------------------------
 *     [class]              | o
 *   --------------------------------------------------
 *     [^class]             | o
 *   --------------------------------------------------
 *     \cC                  | o
 *   --------------------------------------------------
 *     \xXX                 | ?
 *   --------------------------------------------------
 *     \uXXXX               | ?
 *   --------------------------------------------------
 *     \U00YYYYYY           | ?
 *   --------------------------------------------------
 *     \f \n \r \t \v       | o
 *   --------------------------------------------------
 *     \d \D \w \W \s \S    | o
 *   --------------------------------------------------
 *     \c where c is one of | o
 *     [|*+?()              |
 *   --------------------------------------------------
 *     \p{PropertyName}     | X
 *   --------------------------------------------------
 *     \P{PropertyName}     | X
 *   --------------------------------------------------
 *     \p{InBasicLatin}     | X
 *   --------------------------------------------------
 *     \P{InBasicLatin}     | X
 *   --------------------------------------------------
 *     \p{Cyrilic}          | X
 *   --------------------------------------------------
 *     \P{Cyrilic}          | X
 *   --------------------------------------------------
 *     ?                    | o
 *   --------------------------------------------------
 *     *                    | o
 *   --------------------------------------------------
 *     *?                   | o
 *   --------------------------------------------------
 *     +                    | o
 *   --------------------------------------------------
 *     +?                   | o
 *   --------------------------------------------------
 *     {n}                  | o
 *   --------------------------------------------------
 *     {n,}                 | o
 *   --------------------------------------------------
 *     {n,}?                | o
 *   --------------------------------------------------
 *     {n,m}                | o
 *   --------------------------------------------------
 *     {n,m}?               | o
 *   --------------------------------------------------
 *     (regex)              | o
 *   --------------------------------------------------
 *     (?:regex)            | o
 *   --------------------------------------------------
 *     A|B                  | o
 *   --------------------------------------------------
 *     (?P<name>regex)      | o
 *   --------------------------------------------------
 *     ^                    | o
 *   --------------------------------------------------
 *     $                    | o
 *   --------------------------------------------------
 *     \b                   | o
 *   --------------------------------------------------
 *     \B                   | o
 *   --------------------------------------------------
 *     (?=regex)            | o
 *   --------------------------------------------------
 *     (?!=regex)           | o
 *   --------------------------------------------------
 *     (?<=regex)           | X
 *   --------------------------------------------------
 *     (?<!regex)           | X
 *   ==================================================
 *     a-z                  | o
 *   --------------------------------------------------
 *     [a||b] [a--b]        | X
 *     [a~~b] [a&&b]        |
 *   ==================================================
 *     g                    | o
 *   --------------------------------------------------
 *     i                    | o
 *   --------------------------------------------------
 *     m                    | o
 *   --------------------------------------------------
 *     s                    | o
 *   --------------------------------------------------
 *     x                    | o
 *   --------------------------------------------------
**/



//------------------------------------------------------------------------------
// 最大で、TICache.CACHE_SIZE までしか peek できない。
// fix を呼ぶまで TICache.popFront は呼ばれない。
// Bugs:
//  sworks.compo.util.cached_buffer.SliceMaker and std.array.Appender doesn't work when CTFE.
class PeekRange(T)
{
	private TICache!T _entity;
	private const(T)[] _cache;
	private size_t _trail;
	private T _back;

	this( TICache!T e )
	{
		_entity = e;
		_cache = e.rest;
		_trail = 0;
		_back = '\0';
	}

	bool empty() @property const { return _cache.length <= _trail; }
	size_t pos() @property const { return _trail; }
	void pos( size_t t ) @property { assert( t <= _cache.length ); _trail = t; }
	T front() @property const { return _trail < _cache.length ? _cache[ _trail ] : T.init; }
	T back() @property const { return 0 < _trail ? _cache[ _trail-1 ] : _back; }

	void popFront() @property
	{
		if( _trail < _cache.length )
		{
			_trail++;
			if( _cache.length <= _trail ) _cache = _entity.peek( size_t.max );
		}
	}

	immutable(T)[] fix( Slice s )
	{
		immutable(T)[] result = _cache.apply(s).idup;
		discard();
		return result;
	}

	void discard()
	{
		if( 0 < _trail ) _back = _cache[ _trail - 1 ];
		_entity.popFront( _trail );
		_cache = _entity.rest;
		_trail = 0;
	}

	bool reserve( size_t s )
	{
		if( _cache.length < s ) _cache = _entity.peek( size_t.max );
		return s <= _cache.length;
	}
}

//------------------------------------------------------------------------------
struct Slice
{
	size_t head;
	size_t tail;
	bool empty() @property const { return tail <= head; }
	void marge( in Slice r )
	{
		if( r.empty ) return;
		if( tail <= head ){ head = r.head; tail = r.tail; }
		else
		{
			if( r.head < head ) head = r.head;
			if( tail < r.tail ) tail = r.tail;
		}
	}
}
inout(T)[] apply(T)( inout(T)[] arr, in Slice s, size_t base = 0 ) { return arr[ s.head - base .. s.tail - base ]; }

//------------------------------------------------------------------------------
struct FragResult(T)
{
	bool match;
	Slice hit;
	Slice[] captures; // a range of captures must be within the range of hit.
	Slice[immutable(T)[]] named_captures;

	void clear()
	{
		match = false;
		hit = Slice( 0, 0 );
		captures = null;
		named_captures = null;
	}

	bool marge( FragResult!T right )
	{
		if     ( !right.match ) return false;
		else if( !match )
		{
			match = true;
			hit = right.hit;
			captures = right.captures;
			named_captures = right.named_captures;
		}
		else
		{
			hit.marge( right.hit );
			captures ~= right.captures;
			foreach( key, one ; right.named_captures ) named_captures[ key ] = one;
		}
		return true;
	}
}

//------------------------------------------------------------------------------
//
struct MatchResult(T)
{
	PeekRange!T range;
	DRegExp!T regexp;

	immutable(T)[] hit;
	Captures!T captures;

	bool empty() @property const{ return 0 == hit.length; }
	void clear() { hit = null; captures.clear; }

	immutable(T)[] front() @property const { return hit; }
}

//------------------------------------------------------------------------------
struct Captures(T)
{
	private immutable(T)[][] _caps;
	private immutable(T)[][ immutable(T)[] ] _named;
	size_t length() @property const{ return _caps.length; }
	bool empty() @property const{ return 0 == _caps.length; }
	void clear() { _caps = null; _named = null; }

	immutable(T)[] front() @property const{ return 0 < _caps.length ? _caps[0] : []; }
	void popFront() { if( 0 < _caps.length ) _caps = _caps[ 1 .. $ ]; }

	immutable(T)[] opIndex( size_t i ){ return i < _caps.length ? _caps[i] : []; }
	immutable(T)[] opIndex( immutable(T)[] key ){ return _named.get( key, [] ); }

	void opCatAssign( immutable(T)[] c ){ _caps ~= c; }
	void opIndexAssign( immutable(T)[] c, immutable(T)[] key )
	{
		_named[ key ] = c;
		_caps ~= c;
	}
}

//------------------------------------------------------------------------------
struct DRegExp(T)
{
	MODE mode;
	Fragment!T frag;
}

//------------------------------------------------------------------------------
// CTFE でクロージャが使えないのでファンクタで。
interface Fragment(T)
{
	alias F = Fragment;
	alias FR = FragResult!T;
	alias PR = PeekRange!T;
	FR opCall( PR );
	size_t length() @property const;
}

//------------------------------------------------------------------------------
enum MODE : uint
{
	GLOBAL = 0x01,
	IGNORECASE = 0x02,
	MULTILINE = 0x04,
	FREESYNTAX =0x08,
	INVERSE = 0x10,
}

//==============================================================================
class AlwaysMatch(T) : Fragment!T
{
	MODE mode;
	this( MODE m ){ mode = m; }
	size_t length() @property const{ return 1; }

	FR opCall( PR s )
	{
		FR result;
		T t = s.front;
		if( !s.empty && (0==(mode & MODE.MULTILINE) || ('\r' != t && '\n' != t )) )
		{
			result.match = true;
			result.hit.head = s.pos;
			s.popFront;
			result.hit.tail = s.pos;
		}
		return result;
	}

	static F opCall( MODE m ){ return new AlwaysMatch(m); }
}
//------------------------------------------------------------------------------
class SimpleMatch(T) : Fragment!T
{
	MODE mode;
	T c;
	this( MODE m, T c )
	{
		mode = m;
		this.c = c;
		if( mode & MODE.IGNORECASE && 'a' <= c && c <= 'z' ) this.c &= 0xdf;
	}
	size_t length() @property const { return 1; }
	FR opCall( PR s )
	{
		FR result;
		T t = s.front;
		if( 0 < (mode & MODE.MULTILINE) && ('\r'==t || '\n'==t) ) return result;
		if( mode & MODE.IGNORECASE && 'a' <= t && t <= 'z' ) t &= 0xdf;
		if( (0==(mode & MODE.INVERSE)) == ( c == t ) )
		{
			result.match = true;
			result.hit.head = s.pos;
			s.popFront;
			result.hit.tail = s.pos;
		}
		return result;
	}
	static F opCall( MODE m, T c ){ return new SimpleMatch( m, c ); }
}

//------------------------------------------------------------------------------
class RangeMatch(T) : Fragment!T
{
	MODE mode;
	T a, b;
	this( MODE m, T a, T b )
	{
		mode = m;
		this.a = a;
		this.b = b;
		if( mode & MODE.IGNORECASE )
		{
			if( 'a' <= this.a && this.a <= 'z' ) this.a &= 0xdf;
			if( 'a' <= this.b && this.b <= 'z' ) this.b &= 0xdf;
		}
	}
	size_t length() @property const { return 1; }
	FR opCall( PR str )
	{
		FR result;
		T c = str.front;
		if( 0 < (mode & MODE.MULTILINE) && ('\r'==c || '\n'==c) ) return result;
		if( mode & MODE.IGNORECASE && 'a' <= c && c <= 'z' ) c &= 0xdf;
		if( (0==(mode & MODE.INVERSE)) == (a <= c && c <= b) )
		{
			result.match = true;
			result.hit.head = str.pos;
			str.popFront;
			result.hit.tail = str.pos;
		}
		return result;
	}

	static F opCall( MODE m, T a, T b )
	{
		if( a == b ) return new SimpleMatch!T( m, a );
		if( b < a )
		{
			m ^= MODE.INVERSE;
			T t = a; a = b; b = t;
		}
		return new RangeMatch( m, a, b );
	}
}

//------------------------------------------------------------------------------
bool isWord(T)( T c ) { return !c.isASCII || c.isAlphaNum; }
class WordMatch(T) : Fragment!T
{
	MODE mode;
	this( MODE m ){ mode = m; }
	size_t length() @property const { return 1; }
	FR opCall( PR s )
	{
		FR result;
		auto t = s.front;
		if( 0 < (mode & MODE.MULTILINE) && ('\r'==t || '\n'==t) ) return result;
		if( (0==(mode & MODE.INVERSE)) == isWord!T(t) )
		{
			result.match = true;
			result.hit.head = s.pos;
			s.popFront;
			result.hit.head = s.pos;
		}
		return result;
	}
	static F opCall( MODE m ){ return new WordMatch( m ); }
}

//------------------------------------------------------------------------------
class WhiteMatch(T) : Fragment!T
{
	MODE mode;
	this( MODE m ){ mode = m; }
	size_t length() @property const { return 1; }
	FR opCall( PR s )
	{
		FR result;
		auto t = s.front;
		if( 0 < (mode & MODE.MULTILINE) && ('\r'==t || '\n'==t) ) return result;
		if( (0==(mode & MODE.INVERSE)) == t.isWhite )
		{
			result.match = true;
			result.hit.head = s.pos;
			s.popFront;
			result.hit.tail = s.pos;
		}
		return result;
	}
	static F opCall( MODE m ){ return new WhiteMatch(m); }
}

//------------------------------------------------------------------------------
class DigitMatch(T) : Fragment!T
{
	MODE mode;
	this( MODE m ){ mode = m; }
	size_t length() @property const { return 1; }
	FR opCall( PR str )
	{
		FR result;
		auto t = str.front;
		if( 0 < (mode & MODE.MULTILINE) && ('\r'==t || '\n'==t) ) return result;
		if( (0==(mode & MODE.INVERSE)) == t.isDigit )
		{
			result.match = true;
			result.hit.head = str.pos;
			str.popFront;
			result.hit.tail = str.pos;
		}
		return result;
	}
	static F opCall( MODE m ){ return new DigitMatch( m ); }
}

//------------------------------------------------------------------------------
class WordbreakMatch(T) : Fragment!T
{
	MODE mode;
	this( MODE m ){ mode = m; }
	size_t length() @property const { return 0; }
	FR opCall( PR str )
	{
		FR result;
		result.match = (0==(mode & MODE.INVERSE)) == ( isWord!T(str.back) != isWord!T(str.front) );
		if( result.match ) result.hit.head = result.hit.tail = str.pos;
		return result;
	}
	static F opCall( MODE m ){ return new WordbreakMatch( m ); }
}

//------------------------------------------------------------------------------
class LineBeginingMatch(T) : Fragment!T
{
	MODE mode;
	this( MODE m ){ mode = m; }
	size_t length() @property const { return 0; }
	FR opCall( PR str )
	{
		FR result;
		auto t = str.back;
		if     ( '\0' == t ) {}
		else if( 0 == (mode & MODE.MULTILINE) ) return result;
		else if( '\n' == t ) {}
		else if( '\r' == t && '\n' != str.front ){}
		else return result;
		result.match = true;
		result.hit.head = result.hit.tail = str.pos;
		return result;
	}
	static F opCall( MODE m ){ return new LineBeginingMatch( m ); }
}

//------------------------------------------------------------------------------
class LineEndMatch(T) : Fragment!T
{
	MODE mode;
	this( MODE m ){ mode = m; }
	size_t length() @property const { return 0; }
	FR opCall( PR str )
	{
		FR result;
		auto t = str.front;
		if     ( '\0' == t ) {}
		else if( 0 == (mode & MODE.MULTILINE ) ) return result;
		else if( '\r' == t ) {}
		else if( '\n' == t && '\r' != str.back ) {}
		else return result;
		result.match = true;
		result.hit.head = result.hit.tail = str.pos;
		return result;
	}
	static F opCall( MODE m ){ return new LineEndMatch( m ); }
}


//==============================================================================
class MatchAll(T) : Fragment!T
{
	F[] frags;
	size_t l;
	this( F[] f )
	{
		frags = f;
		foreach( one ; f ) l += f.length;
	}
	size_t length() @property const { return l; }
	FR opCall( PR range )
	{
		FR result;
		auto store = range.pos;
		for( size_t i = 0 ; i < frags.length ;  i++ )
		{
			if( !result.marge( frags[i](range) ) ){ range.pos = store; result.clear; break; }
		}
		return result;
	}
	static F opCall( F[] f )
	{
		return 0 < f.length ? new MatchAll( f ) : null;
	}
}

//------------------------------------------------------------------------------
class OrMatch(T) : Fragment!T
{
	F sideA, sideB;
	size_t l;
	this( F a, F b )
	{
		sideA = a;
		sideB = b;
		l = a.length < b.length ? b.length : a.length;
	}
	size_t length() @property const { return l; }
	FR opCall( PR str )
	{
		FR result = sideA( str );
		if( !result.match ) result = sideB( str );
		return result;
	}
	static F opCall( F a, F b )
	{
		if( null is a && null is b ) return null;
		if( null is a ) return b;
		if( null is b ) return a;
		return new OrMatch( a, b );
	}
}

//------------------------------------------------------------------------------
class AmongMatch(T) : Fragment!T
{
	F[] frags;
	this( F[] f ){ frags = f; }
	size_t length() @property const { return 1; }
	FR opCall( PR str )
	{
		FR result;
		for( size_t i = 0 ; i < frags.length ; i++ )
		{
			result = frags[i]( str );
			if( result.match ) break;
		}
		return result;
	}
	static F opCall( F[] f )
	{
		enforce( 0 < f.length, "an expression [class] needs some characters in its inside." );
		return new AmongMatch( f );
	}
}

//------------------------------------------------------------------------------
class TimesMatch(T) : Fragment!T
{
	F prev;
	size_t time;
	size_t l;
	this( F p, size_t t ) { prev = p; time = t; l = p.length * t; }
	size_t length() @property const { return l; }
	FR opCall( PR str )
	{
		FR result;
		size_t store = str.pos;
		for( size_t i = 0 ; i < time; i++ )
		{
			if( !result.marge(prev(str)) ) { str.pos = store; result.clear; break; }
		}
		return result;
	}
	static F opCall( F p, size_t t )
	{
		enforce( null !is p, "an expression {n} needs a precedent expression." );
		if( 0 == t ) return null;
		if( 1 == t ) return p;
		return new TimesMatch( p, t );
	}
}

//------------------------------------------------------------------------------
class GreedyTimesMatch(T) : Fragment!T
{
	F prev;
	F after;
	size_t min, max, l;
	this( F p, size_t mi, size_t ma, F a )
	{
		prev = p;
		min = mi;
		max = ma;
		after = a;
		l = p.length * mi;
		if( null !is a ) l += a.length;
	}
	size_t length() @property const { return l; }
	FR opCall( PR str )
	{
		FR result;
		size_t first = str.pos;
		size_t[] store;
		for( ; !str.empty && store.length <= max ; )
		{
			store ~= str.pos;
			if( !result.marge(prev(str)) ) break;
		}
		if( null !is after )
		{
			for( ; min < store.length ; )
			{
				if( result.marge(after(str))){ break; }
				str.pos = result.hit.tail = store[ $ - 1 ];
				store = store[ 0 .. $-1 ];
			}
		}
		else if( 0 == min )
		{
			result.match = true;
		}
		if( store.length <= min || !result.match ){ str.pos = first; result.clear; }
		return result;
	}
	static F opCall( F p, size_t mi, size_t ma, F a )
	{
		enforce( null !is p, "an expression {n,m} needs a precedent expression." );
		enforce( mi <= ma, "about an expression {n,m}, n must be less than m." );
		if( mi == ma )
		{
			F[] fs;
			fs.put( TimesMatch!T( p, mi ) );
			fs.put( a );
			return MatchAll!T( fs );
		}
		return new GreedyTimesMatch( p, mi, ma, a );
	}
}

//------------------------------------------------------------------------------
class LazyTimesMatch(T) : Fragment!T
{
	F prev;
	F after;
	size_t min, max;
	size_t l;
	this( F p, size_t mi, size_t ma, F a )
	{
		prev = p;
		min = mi;
		max = ma;
		after = a;
		l = p.length * mi;
		if( null !is a ) l += a.length;
	}
	size_t length() @property const { return l; }
	FR opCall( PR str )
	{
		FR result;
		size_t first = str.pos;
		size_t store;
		size_t i;
		for( i = 0 ; !str.empty && i < max ; i++ )
		{
			if( min <= i )
			{
				store = str.pos;
				if( result.marge(after(str)) ) break;
				str.pos = store;
			}
			if( !result.marge(prev(str)) ) break;
		}
		if( i < min || !result.match ) { str.pos = first; result.clear; }
		return result;
	}

	static F opCall( F p, size_t mi, size_t ma, F a )
	{
		enforce( null !is p, "an expression {n,m}? needs a precedent expression." );
		enforce( mi <= ma, "about an expression {n,m}, n must be less than m." );
		if( mi == ma )
		{
			F[] fs;
			fs.put( TimesMatch!T( p, mi ) );
			fs.put( a );
			return MatchAll!T( fs );
		}
		return new LazyTimesMatch( p, mi, ma, a );
	}

}

//------------------------------------------------------------------------------
class CaptureMatch(T) : Fragment!T
{
	F cont;
	size_t l;
	this( F c ){ cont = c; l = null !is cont ? cont.length : 0; }
	size_t length() @property const { return l; }
	FR opCall( PR str )
	{
		FR result;
		if( null !is cont )
		{
			size_t store = str.pos;
			result = cont( str );
			if( result.match ) result.captures ~= result.hit;
			else { str.pos = store; result.clear; }
		}
		else
		{
			result.match = true;
			result.hit.head = result.hit.tail = str.pos;
		}

		return result;
	}

	static F opCall( F c ) { return new CaptureMatch( c ); }
}

//------------------------------------------------------------------------------
class NamedCaptureMatch(T) : Fragment!T
{
	immutable(T)[] name;
	F cont;
	size_t l;
	this( immutable(T)[] n, F c ){ name = n; cont = c; l = null !is cont ? cont.length : 0; }
	size_t length() @property const { return l; }
	FR opCall( PR str )
	{
		FR result;
		if( null !is cont )
		{
			size_t store = str.pos;
			result = cont( str );
			if( result.match ) result.named_captures[ name ] = result.hit;
			else { str.pos = store; result.clear; }
		}
		else
		{
			result.match = true;
			result.hit.head = result.hit.tail = str.pos;
		}
		return result;
	}

	static F opCall( immutable(T)[] n, F c ){ return new NamedCaptureMatch( n, c ); }
}

//------------------------------------------------------------------------------
class LookAheadMatch(T) : Fragment!T
{
	MODE mode;
	F cont;
	size_t l;
	this( F c, MODE m )
	{
		cont = c;
		mode = m;
		l = 0 < (mode & MODE.INVERSE) && null !is cont ? cont.length : 0;
	}
	size_t length() @property const { return l; }
	FR opCall( PR str )
	{
		FR result;
		if( null !is cont )
		{
			auto store = str.pos;
			result = cont( str );
			result.match = (0==(mode & MODE.INVERSE)) == result.match;
			result.hit.tail = result.hit.head;
			if( !result.match ) str.pos = store;
		}
		else
		{
			result.match = 0==(mode & MODE.INVERSE);
			if( result.match ) result.hit.head = result.hit.tail = str.pos;
		}
		return result;
	}

	static F opCall( F c, MODE m ){ return new LookAheadMatch( c, m ); }
}

//==============================================================================

//------------------------------------------------------------------------------
uint toHex(T)( const(T)[] str )
{
	uint result, c;
	for( size_t i = 0 ; i < str.length ; i++ )
	{
		result <<= 4;
		c = str[i];
		if     ( '0' <= c && '9' <= c ) result |= ( c & 0x0f );
		else if( 'A' <= c && 'F' <= c ) result |= c - 'A' + 10;
		else if( 'a' <= c && 'f' <= c ) result |= c - 'a' + 10;
		else break;
	}
	return result;
}

//------------------------------------------------------------------------------
Fragment!T escapeParser(T)( T c, ref const(T)[] pattern, MODE mode )
{
	if     ( 'c' == c && 0 < pattern.length ) // control
	{
		c = pattern[0]; pattern = pattern[ 1 .. $ ];
		return SimpleMatch!T( mode, c & 0xbf );
	}
	else if( 'x' == c && 1 < pattern.length )
	{
		c = cast(T)(pattern[ 0 .. 2 ].toHex!T);
		pattern = pattern[ 2 .. $ ];
		return SimpleMatch!T( mode, c );
	}
	else if( 'u' == c && 3 < pattern.length )
	{
		auto h = cast(wchar)(pattern[ 0 .. 4 ].toHex!T);
		T[] str;
		static if( is( T == jchar ) ) str = cast(jchar[])( h.to!(char[]));
		else str = h.to!(T[]);
		pattern = pattern[ 4 .. $ ];
		if( 1 == str.length ) return SimpleMatch!T( mode, str[0] );
		auto funcs = new Fragment!T[ str.length ];
		for( size_t i = 0 ; i < str.length ; i++ ) funcs[i] = SimpleMatch!T( mode, str[i] );
		return MatchAll!T( funcs );
	}
	else if( 'U' == c && 7 < pattern.length )
	{
		auto h = cast(dchar)(pattern[ 0 .. 8 ].toHex!T);
		T[] str;
		static if( is( T == jchar ) ) str = cast(jchar[])(h.to!(char[]));
		else str = h.to!(T[]);
		pattern = pattern[ 8 .. $ ];
		if( 1 == str.length ) return SimpleMatch!T( mode, str[0] );
		auto funcs = new Fragment!T[ str.length ];
		for( size_t i = 0 ; i < str.length ; i++ ) funcs[i] = SimpleMatch!T( mode, str[i] );
		return MatchAll!T( funcs );
	}
	else if( 'f' == c ) return SimpleMatch!T( mode, '\f' );
	else if( 'n' == c ) return SimpleMatch!T( mode, '\n' );
	else if( 'r' == c ) return SimpleMatch!T( mode, '\r' );
	else if( 't' == c ) return SimpleMatch!T( mode, '\t' );
	else if( 'v' == c ) return SimpleMatch!T( mode, '\v' );
	else if( 'd' == c ) return DigitMatch!T( mode );
	else if( 'D' == c ) return DigitMatch!T( mode ^ MODE.INVERSE );
	else if( 'w' == c ) return WordMatch!T( mode );
	else if( 'W' == c ) return WordMatch!T( mode ^ MODE.INVERSE );
	else if( 's' == c ) return WhiteMatch!T( mode );
	else if( 'S' == c ) return WhiteMatch!T( mode ^ MODE.INVERSE );
	else if( 'b' == c ) return WordbreakMatch!T( mode );
	else if( 'B' == c ) return WordbreakMatch!T( mode ^ MODE.INVERSE );
	else if( 'p' == c ) throw new Exception( "\\p is not implemented yet" );
	else if( 'P' == c ) throw new Exception( "\\P is not implemented yet" );
	else return SimpleMatch!T( mode, c );
}

//------------------------------------------------------------------------------
void replaceLast(T)( ref Fragment!T[] funcs, Fragment!T f ){ if( null !is f && 0 < funcs.length ) funcs[$-1] = f; }
Fragment!T amongParser(T)( ref const(T)[] pattern, MODE mode )
{
	Fragment!T[] funcs;
	if( 0 < pattern.length && '^' == pattern[0] ) { mode ^= MODE.INVERSE; pattern = pattern[ 1 .. $ ]; }
	for( T c = '\0', prev ; 0 < pattern.length ; )
	{
		prev = c; c = pattern[0]; pattern = pattern[ 1 .. $ ];
		if     ( '\\' == prev ) funcs ~= escapeParser( c, pattern, mode );
		else if( ']' == c ) break;
		else if( '-' == c )
		{
			if( '\0' == prev || 0 == pattern.length ) funcs.put( SimpleMatch!T( mode, c ) );
			else
			{
				c = pattern[0]; pattern = pattern[ 1 .. $ ];
				funcs.replaceLast( RangeMatch!T( mode, prev, c ) );
			}
		}
		else funcs.put( SimpleMatch!T( mode, c ) );
	}
	return AmongMatch!T( funcs );
}

//------------------------------------------------------------------------------
uint chompNumber(T)( ref const(T)[] pattern )
{
	uint result = 0;
	for( ; 0 < pattern.length && pattern[0].isDigit ; pattern = pattern[ 1 .. $ ] )
	{
		result *= 10;
		result += pattern[0] & 0x0f;
	}
	return result;
}

//------------------------------------------------------------------------------
Fragment!T braceParser(T)( Fragment!T prev, ref const(T)[] pattern, MODE mode )
{
	uint start = 0;
	uint end = 0;

	start = pattern.chompNumber!T;
	enforce( 0 < pattern.length );

	if     ( ',' == pattern[0] ) { pattern = pattern[ 1 .. $ ]; end = uint.max; }
	else if( '}' == pattern[0] ) { pattern = pattern[ 1 .. $ ]; return TimesMatch!T( prev, start ); }
	end = pattern.chompNumber;
	if( 0 == end || end < start ) end = uint.max;
	enforce( 0 < pattern.length && '}' == pattern[0] );
	auto rest = pattern[ 1 .. $ ];
	pattern = [];
	if( 0 < rest.length && '?' == rest[0] ) return LazyTimesMatch!T( prev, start, end, dirtyRegex!T( rest[ 1 .. $ ], mode ).frag );
	else return GreedyTimesMatch!T( prev, start, end, dirtyRegex!T( rest, mode ).frag );
}

immutable(T)[] getCaptureName(T)( ref const(T)[] pattern )
{
	enforce( 0 < pattern.length && '<' == pattern[0] );
	pattern = pattern[ 1 .. $ ];
	size_t i;
	for( ; i < pattern.length ; i++ )
	{
		if     ( '\\' == pattern[i] ) i++;
		else if( '>' == pattern[i] ) break;
	}
	immutable(T)[] name = pattern[ 0 .. i ].idup;
	if( i < pattern.length ) i++;
	pattern = pattern[ i .. $ ];
	return name;
}

//------------------------------------------------------------------------------
Fragment!T parenthesisParser(T)( const(T)[] pattern, MODE mode )
{
	if( pattern.length < 2 || '?' != pattern[0] ) return CaptureMatch!T( dirtyRegex( pattern, mode ).frag );
	if     ( ':' == pattern[1] ) return dirtyRegex( pattern[ 2 .. $ ], mode ).frag;
	else if( 'P' == pattern[1] )
	{
		pattern = pattern[ 2 .. $ ];
		auto name = pattern.getCaptureName;
		return NamedCaptureMatch!T( name, dirtyRegex( pattern, mode ).frag );
	}
	else if( '=' == pattern[1] )
	{
		return LookAheadMatch!T( dirtyRegex( pattern[ 2 .. $ ], mode ).frag, mode );
	}
	else if( '!' == pattern[1] )
	{
		return LookAheadMatch!T( dirtyRegex( pattern[ 2 .. $ ], mode ).frag, mode ^ MODE.INVERSE );
	}
	else if( '<' == pattern[1] )
	{
		throw new Exception( "look behind assertions, (?<=regex) and (?<!regex), are not implemented yet." );
	}
	enforce( false );
	return null;
}

//==============================================================================
DRegExp!T dirtyRegex( T )( const(T)[] pattern, string m = "" )
{
	MODE mode;
	foreach( one ; m ) { switch( one & 0xdf )
	{
		       case 'M': mode |= MODE.MULTILINE;
		break; case 'I': mode |= MODE.IGNORECASE;
		break; case 'G': mode |= MODE.GLOBAL;
		break; case 'X': mode |= MODE.FREESYNTAX;
		break; case 'S': mode &= !MODE.MULTILINE;
		break; default:
		break;
	}}
	return dirtyRegex!T( pattern, mode );
}


void put(T)( ref Fragment!T[] funcs, Fragment!T f ){ if( null !is f ) funcs ~= f; }

DRegExp!T dirtyRegex( T )( const(T)[] pattern, MODE mode )
{
	Fragment!T[] funcs;

	auto original = pattern;
	try
	{
		for( T c = '\0' ; 0 < pattern.length ; )
		{
			c = pattern[0]; pattern = pattern[ 1 .. $ ];

			if     ( 0 < (mode & MODE.FREESYNTAX) && c.isWhite ){ }
			else if( '\\' == c && 0 < pattern.length )
			{
				c = pattern[0]; pattern = pattern[ 1 .. $ ];
				funcs.put( escapeParser( c, pattern, mode ) );
			}
			else if( '.' == c ) funcs.put( AlwaysMatch!T( mode ) );
			else if( '^' == c ) funcs.put( LineBeginingMatch!T( mode ) );
			else if( '$' == c ) funcs.put( LineEndMatch!T( mode ) );
			else if( '[' == c ) funcs.put( amongParser( pattern, mode ) );
			else if( '{' == c && 0 < funcs.length ) funcs.replaceLast( braceParser( funcs[$-1], pattern, mode ) );
			else if( '?' == c && 0 < funcs.length )
			{
				funcs.replaceLast( GreedyTimesMatch!T( funcs[$-1], 0, 1, dirtyRegex!T( pattern, mode ).frag ) );
				break;
			}
			else if( '*' == c && 0 < funcs.length )
			{
				if( 0 < pattern.length && '?' == pattern[0] )
				{
					pattern = pattern[ 1 .. $ ];
					funcs.replaceLast( LazyTimesMatch!T( funcs[ $-1 ], 0, uint.max, dirtyRegex!T( pattern, mode ).frag ) );
					break;
				}
				else
				{
					funcs.replaceLast( GreedyTimesMatch!T( funcs[ $-1 ], 0, uint.max, dirtyRegex!T( pattern, mode ).frag ) );
					break;
				}
			}
			else if( '+' == c && 0 < funcs.length )
			{
				if( 0 < pattern.length && '?' == pattern[0] )
				{
					pattern = pattern[ 1 .. $ ];
					funcs.replaceLast( LazyTimesMatch!T( funcs[ $-1 ], 1, uint.max, dirtyRegex!T( pattern, mode ).frag ) );
					break;
				}
				else
				{
					funcs.replaceLast( GreedyTimesMatch!T( funcs[ $-1 ], 1, uint.max, dirtyRegex!T( pattern, mode ).frag ) );
					break;
				}
			}
			else if( '|' == c )
			{
				auto sideA = MatchAll!T( funcs );
				funcs = [];
				funcs.put( OrMatch!T( sideA, dirtyRegex!T( pattern, mode ).frag ) );
				pattern = [];
			}
			else if( '(' == c )
			{
				for( size_t i = 0, nest = 1 ; ; i++ )
				{
					enforce( i < pattern.length, "a parenthesis is not closed." );
					if     ( '\\' == pattern[i] ) i++;
					else if( '(' == pattern[i] ) nest++;
					else if( ')' == pattern[i] )
					{
						enforce( 0 < nest, "detect mismatch parenthesis" );
						nest--;
						if( 0 == nest )
						{
							funcs.put( parenthesisParser!T( pattern[ 0 .. i ], mode ) );
							pattern = pattern[ i+1 .. $ ];
							break;
						}
					}
				}

			}
			else funcs.put( SimpleMatch!T( mode, c ) );
		}

		return DRegExp!T( mode, MatchAll!T(funcs) );
	}
	catch( Exception e )
	{
		string cont;
		static if( is( T : jchar ) ) cont = original[ 0 .. $ - pattern.length ].idup.c;
		else cont = original[ 0 .. $ - pattern.length ].to!string;
		throw new Exception( e.msg ~ newline ~ "something wrong around," ~ newline ~ cont ~ "<<<<<" );
	}
}

//------------------------------------------------------------------------------
MatchResult!T searchNext(T)( PeekRange!T range, DRegExp!T reg )
{
	MatchResult!T mr;
	FragResult!T fr;
	for( ; !range.empty ; range.popFront )
	{
		fr = reg.frag( range );
		if( fr.match )
		{
			auto str = range.fix( fr.hit );
			mr.hit = str;
			foreach( one ; fr.captures ) mr.captures ~= str.apply( one, fr.hit.head );
			foreach( key, one ; fr.named_captures ) mr.captures[ key ] = str.apply( one, fr.hit.head );
			break;
		}
	}
	return mr;
}

//------------------------------------------------------------------------------
MatchResult!T popFront(T)( ref MatchResult!T m )
{
	if( 0 == (m.regexp.mode & MODE.GLOBAL) ) m.clear;
	else m = searchNext!T( m.range, m.regexp );
	return m;
}

//------------------------------------------------------------------------------
size_t startsWith(T)( PeekRange!T range, DRegExp!T[] regexp ... )
{
	FragResult!T fr;
	for( size_t i = 0 ; i < regexp.length ; i++ )
	{
		if( regexp[i].frag( range ) ) { range.discard(); return i+1; }
	}
	return 0;
}

//------------------------------------------------------------------------------
MatchResult!T beginWith(T)( PeekRange!T range, DRegExp!T regex )
{
	MatchResult!T mr;
	auto fr = regex.frag( range );
	if( fr.match )
	{
		mr.hit = range.fix( fr.hit );
		foreach( one ; fr.captures ) mr.captures ~= mr.hit.apply( one, fr.hit.head );
		foreach( key, one ; fr.named_captures ) mr.captures[ key ] = mr.hit.apply( one, fr.hit.head );
	}
	return mr;
}

///////////////XXXXXXXXXXXXXXXXXX T H E  E N D XXXXXXXXXXXXXXXXXX\\\\\\\\\\\\\\\
debug( dregex ):

import std.stdio;

string func()
{
	auto cont = new PeekRange!char( new TWholeCache!char("hello world") );
	auto c = dirtyRegex( "good-bye|w\\wr(ld)" );
	auto mr = cont.searchNext!char( c );
	return mr.hit;
}
/*
enum str = func();
//*/

void main()
{
/*
	writeln( func() );
/*
	writeln( str );
//*/

	auto cont = new PeekRange!char( new TWholeCache!char( "hello world" ) );
	auto r = dirtyRegex( "[^o]*g?" );
	auto mr = cont.searchNext( r );
	writeln( "\"", mr.hit, "\"" );
	for( ; !mr.captures.empty ; mr.captures.popFront )
	{
		writeln( "(", mr.captures.front, ")" );
	}
}
