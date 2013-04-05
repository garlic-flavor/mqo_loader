/** GLSL のハンドリング
 * Version:      0.0014(dmd2.062)
 * Date:         2013-Apr-06 01:08:29
 * Authors:      KUMA
 * License:      CC0
 */
module sworks.compo.gl.glsl;

import std.conv;
import sworks.compo.gl.util;
debug import std.stdio;

/*CCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCC*\
|*|                                  Shader                                  |*|
\*CCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCC*/
/**
 * シェーダのコンパイルと ID の管理
 */
class Shader
{
	GLuint id;
	alias id this;

	/**
	 * Params:
	 *   shader_type = glCreateShader の引数
	 *   cont        = シェーダの中身
	 * Throws:
	 *   Exception コンパイルが失敗した際に投げられる。$(BR)
	 *             中身に OpenGL が生成したエラーメッセージを含む。
	 */
	this( uint shader_type, const(char)[] cont )
	{
		id = glCreateShader( shader_type );
		char* cont_p = cast(char*)cont.ptr;
		int l_p = cont.length;
		glShaderSource( id, 1, &cont_p, &l_p );
		glCompileShader( id );
		int compiled;
		glGetShaderiv( id, GL_COMPILE_STATUS, &compiled );
		if( GL_TRUE != compiled )
		{
			int max_length;
			glGetShaderiv( id, GL_INFO_LOG_LENGTH, &max_length );
			char[] log = new char[ max_length ];
			int log_length;
			glGetShaderInfoLog( id, max_length, &log_length, log.ptr );
			throw new Exception( log[ 0 .. log_length ].idup );
		}
	}

	/// 終了処理を実行して下さい。
	void clear() { glDeleteShader( id ); }
}

/*CCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCC*\
|*|                              ShaderProgram                               |*|
\*CCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCC*/
/**
 * シェーダのリンクと uniform の管理。
 */
class ShaderProgram
{
	GLuint id;
	alias id this;

	/**
	 * Params:
	 *   s = コンパイル済みの物を渡して下さい。
	 */
	this( Shader[] s ... )
	{
		id = glCreateProgram();
		assert( id );
		foreach( one ; s ) glAttachShader( id, one );
	}
	/// 終了処理を実行して下さい。
	void clear() {glDeleteProgram( id );}
	/// リンク前ならば Shader を後から追加できます。
	ShaderProgram opOpAssign( string OP : "+" )( Shader s ) { glAttachShader( id, shader ); return this; }

	/**
	 * シェーダをリンクします。
	 * Throws:
	 *   Exception リンクに失敗した時に投げられる。$(BR)
	 *             中身に OpenGL が生成したエラーメッセージを含んでいる。
	 */
	ShaderProgram link()
	{
		glLinkProgram( id );
		int linked;
		glGetProgramiv( id, GL_LINK_STATUS, &linked );
		if( GL_TRUE != linked )
		{
			int max_length;
			glGetProgramiv( id, GL_INFO_LOG_LENGTH, &max_length );
			char[] log = new char[ max_length ];
			int log_length;
			glGetProgramInfoLog( id, max_length, &log_length, log.ptr );
			throw new Exception( log[ 0 .. log_length ].idup );
		}

		return this;
	}

	// glProgramUniform~ の関数名を生成する。
	static private string prog_name( T,size_t N )()
	{
		string result = "glProgramUniform";
		static if     ( 1 == N ) result ~= "1";
		else static if( 2 == N ) result ~= "2";
		else static if( 3 == N ) result ~= "3";
		else static if( 4 == N ) result ~= "4";
		else static if( 9 == N ) result ~= "Matrix3";
		else static if( 16 == N ) result ~= "Matrix4";

		static if     ( is( T == int ) ) result ~= "iv";
		else static if( is( T == uint ) ) result ~= "uiv";
		else static if( is( T : float ) ) result ~= "fv";
		return result;
	}

	/**
	 * uniform 変数のロケーションを返す。
	 * Params:
	 *   NAME = 変数名
	 *   N    = 配列の添字
	 */
	GLuint opDispatch( string NAME )() { return glGetUniformLocation( id, NAME.ptr ); }
	/// ditto
	GLuint opIndex( string NAME ) { return glGetUniformLocation( id, NAME.ptr ); }
	/// ditto
	GLuint opIndex( string NAME, size_t N )
	{
		return glGetUniformLocation( id, ( NAME ~ "[" ~ N.to!string ~ "]\0" ).ptr );
	}

	/**
	 * 変数名を指定して uniform 変数に値を設定する。$(BR)
	 * ロケーションを指定するよりもオーバーヘッドがある。
	 * Warning:
	 *   引数 value の型は正しいですか？ int と uint は明確に区別され、関数呼び出しの失敗は検知されません!
	 * Bugs:
	 *   対応していない型があります。$(BR)
	 *   四次元正方行列以外の行列型は失敗します。$(BR)
	 */
	void opDispatch( string NAME, TYPE )( in TYPE value )
	{
		opIndexAssign( value, glGetUniformLocation( id, NAME.ptr ) );
	}
	/// ditto
	void opDispatch( string NAME, TYPE )( ref const(TYPE) value )
	{
		opIndexAssign( value, glGetUniformLocation( id, NAME.ptr ) );
	}
	/// ditto
	void opIndexAssign(TYPE)( in TYPE value, const(char)* name )
	{
		opIndexAssign( value, glGetUniformLocation( id, name ) );
	}
	/// ditto
	void opIndexAssign( TYPE )( ref const(TYPE) value, const(char)* name )
	{
		opIndexAssign( value, glGetUniformLocation( id, name ) );
	}
	/// ditto
	void opIndexAssign( TYPE )( in TYPE value, string name, size_t idx )
	{
		opIndexAssign( value, glGetUniformLocation( id, ( name ~ "[" ~ idx.to!string ~ "]\0" ).ptr  ) );
	}
	/// ditto
	void opIndexAssign( TYPE )( ref const(TYPE) value, string name, size_t idx )
	{
		opIndexAssign( value, glGetUniformLocation( id, ( name ~ "[" ~ idx.to!string ~ "]\0" ).ptr  ) );
	}

	/**
	 * ロケーションを指定して uniform 変数に値を代入する。
	 */
	void opIndexAssign(TYPE)( in TYPE value, GLuint loc ){ opIndexAssign( value, loc ); }
	void opIndexAssign( TYPE )( ref const(TYPE) value, GLuint loc )
	{
		static if     ( is( TYPE T : T[N], size_t N ) )
		{
			static if( 4 < N )
				mixin( prog_name!(T,N) )( id, loc, 1, false, value.ptr );
			else
				mixin( prog_name!(T,N) )( id, loc, 1, value.ptr );
		}
		else static if( is( TYPE T : T[] ) )
		{
			static if( is( T TT : TT[N], size_t N ) )
			{
				static if( 4 < N )
					mixin( prog_name!(TT,N) )( id, loc, value.length, false, cast(TT*)value.ptr );
				else
					mixin( prog_name!(TT,N) )( id, loc, value.length, cast(TT*)value.ptr );
			}
			else mixin( prog_name!(T,1) )( id, loc, value.length, value.ptr );
		}
		else mixin( prog_name!(TYPE,1) )( id, loc, 1, &value );
	}

}


/*CCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCC*\
|*|                            VertexArrayObject                             |*|
\*CCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCC*/
/**
 * VAO を扱う。$(BR)
 * 1連の頂点配列につき1インスタンスを想定している。$(BR)
 * 複数のインデックス配列を登録できる。
 */
class VertexArrayObject
{
	GLuint id;
	alias id this;
	GLuint[] buffers;
	ShaderProgram program;

	/**
	 * Params:
	 *   program = リンク済みの ShaderProgram を渡して下さい。
	 *   vertex
	 */
	this(VERTEX)( ShaderProgram program, VERTEX vertex )
	{
		this.program = program;
		glGenVertexArrays( 1, &id );
		setVertex(vertex);
	}
	/// 終了処理を実行して下さい。
	void clear()
	{
		glDeleteVertexArrays( 1, &id ); id = 0;
		glDeleteBuffers( buffers.length, buffers.ptr ); buffers = null;
	}

	// 新しいバッファオブジェクトを生成する。
	private GLuint newBO()
	{
		buffers.length = buffers.length+1;
		glGenBuffers( 1, &(buffers[$-1]) );
		return buffers[$-1];
	}

	// 頂点配列を登録する。
	private GLuint setVertex(VERTEX)( VERTEX[] v ) @property
	{
		glBindVertexArray( id );
		auto buf = newBO;
		int prev_buffer; glGetIntegerv( GL_ARRAY_BUFFER_BINDING, &prev_buffer );
		glBindBuffer( GL_ARRAY_BUFFER, buf );
		glBufferData( GL_ARRAY_BUFFER, VERTEX.sizeof * v.length, v.ptr, GL_STATIC_DRAW );

		foreach( one ; __traits( derivedMembers, VERTEX ) )
		{
			alias typeof( __traits( getMember, v[0], one ) ) TYPE;
			static if     ( is( TYPE T : T[N], size_t N ) )
			{
				auto location = glGetAttribLocation( program, one.ptr );
				if( location < 0 ) continue;
				glEnableVertexAttribArray( location );
				static if     ( is( T : float ) )
					glVertexAttribPointer( location, N, GL_FLOAT, 0, VERTEX.sizeof
					                     , cast(void*)__traits( getMember, v[0], one ).offsetof );
				else static if( is( T : byte ) )
					glVertexAttribPointer( location, N, GL_BYTE, 0, VERTEX.sizeof
					                     , cast(void*)__traits( getMember, v[0], one ).offsetof );
				else static if( is( T : ubyte ) )
					glVertexAttribPointer( location, N, GL_UNSIGNED_BYTE, 0, VERTEX.sizeof
					                     , cast(void*)__traits( getMember, v[0], one ).offsetof );
				else static if( is( T : short ) )
					glVertexAttribPointer( location, N, GL_SHORT, 0, VERTEX.sizeof
					                     , cast(void*)__traits( getMember, v[0], one ).offsetof );
				else static if( is( T : ushort ) )
					glVertexAttribPointer( location, N, GL_UNSIGNED_SHORT, 0, VERTEX.sizeof
					                     , cast(void*)__traits( getMember, v[0], one ).offsetof );
				else static if( is( T : int ) )
					glVertexAttribPointer( location, N, GL_INT, 0, VERTEX.sizeof
					                     , cast(void*)__traits( getMember, v[0], one ).offsetof );
				else static if( is( T : uint ) )
					glVertexAttribPointer( location, N, GL_UNSIGNED_INT, 0, VERTEX.sizeof
					                     , cast(void*)__traits( getMember, v[0], one ).offsetof );
				else static if( is( T : double ) )
					glVertexAttribPointer( location, N, GL_DOUBLE, 0, VERTEX.sizeof
					                     , cast(void*)__traits( getMember, v[0], one ).offsetof );
			}
		}

		glBindBuffer( GL_ARRAY_BUFFER, prev_buffer );
		glBindVertexArray( 0 );
		return buf;
	}

	/**
	 * コンストラクタで指定した頂点配列に使用するインデックス配列を指定する。複数回指定できる。$(BR)
	 * Params:
	 *   idx = 頂点配列
	 * Return:
	 *   入力された index を使って glDrawElements を呼び出すデリゲートを返す。$(BR)
	 *   このデリゲートは内部的に保存されるわけではないので、複数のインデックスを指定する場合は
	 *   ユーザ側で保持して下さい。$(BR)
	 */
	void delegate() getDrawer( GLenum MODE, T)( in T[] idx )
	{
		auto buf = newBO;
		glBindVertexArray( id );
		int prev_buffer; glGetIntegerv( GL_ELEMENT_ARRAY_BUFFER_BINDING, &prev_buffer );
		glBindBuffer( GL_ELEMENT_ARRAY_BUFFER, buf );
		glBufferData( GL_ELEMENT_ARRAY_BUFFER, T.sizeof * idx.length, idx.ptr, GL_STATIC_DRAW );

		glBindBuffer( GL_ELEMENT_ARRAY_BUFFER, prev_buffer );
		glBindVertexArray( 0 );

		return
		{
			glBindVertexArray( id );
//			int prev_buffer; glGetIntegerv( GL_ELEMENT_ARRAY_BUFFER_BINDING, &prev_buffer );
			glBindBuffer( GL_ELEMENT_ARRAY_BUFFER, buf );
//			int prev_program; glGetIntegerv( GL_CURRENT_PROGRAM, &prev_program );
			glUseProgram( program );

			static if     ( is( T : ubyte ) )
				glDrawElements( MODE, idx.length, GL_UNSIGNED_BYTE, null );
			else static if( is( T : ushort ) )
				glDrawElements( MODE, idx.length, GL_UNSIGNED_SHORT, null );
			else static if( is( T : uint ) )
				glDrawElements( MODE, idx.length, GL_UNSIGNED_INT, null );
			else static assert( 0, T.stringof ~ " is not supported as a type for index array." );

//			glUseProgram( prev_program );
//			glBindBuffer( GL_ELEMENT_ARRAY_BUFFER, prev_buffer );
			glBindVertexArray( 0 );
		};
	}
}
