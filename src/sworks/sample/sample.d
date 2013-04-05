/** デモ
 * Version:      0.0014(dmd2.062)
 * Date:         2013-Apr-06 01:08:29
 * Authors:      KUMA
 * License:      CC0
*/
module sworks.sample.sample;
import std.random, std.math;
import sworks.compo.util.matrix; //< Vector3f、Matrix4f、Quaternionf の定義がある。
import sworks.compo.gl.util; //< OpenGL のポーティングを読み込んでいる。
import sworks.compo.gl.glsl; //< GLSL のラッパがある。
import sworks.compo.sdl.util; //< SDLIdleWindowMix の定義がある。
import sworks.compo.sdl.iconv; //< UTF-8 -> SHIFT-JIS の変換をする。getIConvInitializer の定義がある。
import sworks.compo.sdl.image; //< テクスチャ読み込みとかしてる。
import sworks.compo.sdl.gl; //< getGLInitializer の定義がある。

import sworks.mqo.mikoto; //< MikotoActor がある。

import std.stdio;
debug import sworks.compo.util.dump_members; //< デバグ用。クラスのメンバをダンプする。

// 頂点情報
struct SdefVertex
{
	@VLD_POSITION Vector3f pos; /// 位置
	@VLD_TEXTURE UVf uv; /// テクスチャ座標
	alias pos this;

	@VLD_MATRIX int[4] mat = [ -1, -1, -1, -1 ]; /// 影響を受ける変換行列
	@VLD_INFLUENCE float[4] influence = [ 0f, 0, 0, 0 ]; /// それぞれの行列の影響度。∫= 1
}
alias Actor = MikotoActor!SdefVertex;

// メインフレーム
class MQOTest
{ mixin SDLIdleWindowMix!() SWM;
	enum WIDTH = 640;
	enum HEIGHT = 480;

	Actor dsan;
	DsanDrawer dsan_drawer;

	Matrix4f projlook;

	OBBoxDrawer obbox_drawer;
	Color4f obbox_color;

	OBBTestBox bb;
	Bone[] collide_bones;

	WazaList waza;

	this()
	{
		SWM.ctor( SDL_INIT_VIDEO, "SDL_app", WIDTH, HEIGHT, SDL_WINDOW_OPENGL, 30
		        , getImageInitializer( IMG_INIT_JPG )
		        , getGLInitializer!DerelictGL3( true, 16, 8, 8, 8, 8 )
		        , getIConvInitializer() );

		DerelictGL3.reload();

		scope auto converter = new IConvConverter!( "UTF-8", "SHIFT-JIS", char, 64 );
		string toUTF8( jstring sjis ) { return converter( sjis ); }


			/// ベンチ用
//			writeln( "perse start" );
//			uint st = SDL_GetTicks();
		dsan = new Actor( &toUTF8, "dsan\\DさんMove.mks", "dsan\\normal1.mkm" );
//			writeln( "ready : ", SDL_GetTicks() - st );

		dsan.attach( "normal1" );

		glClearColor( 0.0, 0.7, 0.0, 1.0 );
		glClearDepth( 1.0 );

		glViewport( 0, 0, WIDTH, HEIGHT );

		glEnable( GL_DEPTH_TEST );
		glDepthFunc( GL_LESS );

		glEnable( GL_CULL_FACE );
		glCullFace( GL_BACK );

		waza = new WazaList( "image\\技表.jpg" );

		projlook = Matrix4f.orthoMatrix( -320, 320, -240, 240, 1000, 2000 )
			* Matrix4f.lookAtMatrix( [ -48.4750, 106.9941, 1500.0 ], [ 0, 0, 0 ], [ 0, 1, 0 ] );
		dsan_drawer = new DsanDrawer( dsan, projlook, &toUTF8 );

		obbox_drawer = new OBBoxDrawer( projlook );
		obbox_color = Color4f( 0, 0, 0, 1 );

		bb = new OBBTestBox( );
	}

	void clear()
	{
		dsan_drawer.clear();
		obbox_drawer.clear();
		waza.clear();
		SWM.dtor;
	}

	void update( uint interval )
	{
		dsan_drawer.update( interval );
		dsan.update( interval );

		bb.update( interval );

		collide_bones = dsan.collideBones( bb.bbox );
	}

	void draw()
	{
		glClear( GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT );

		dsan_drawer.draw();
		drawBonesBbox( dsan_drawer.world, collide_bones, obbox_drawer, 2, obbox_color );
		bb.draw( obbox_drawer, dsan_drawer.world );
		waza.draw();

		SDL_GL_SwapWindow( window );
	}

	bool isnormal = true;
	void sdl_keydown( ref SDL_KeyboardEvent ke )
	{
		if     ( SDLK_a == ke.keysym.sym )
		{
			dsan.interrupt( "punch1", 0.1 );
		}
		if     ( SDLK_s == ke.keysym.sym )
		{
			dsan.interrupt( "punch2", 0.1 );
		}
		if     ( SDLK_d == ke.keysym.sym )
		{
			dsan.interrupt( "punch3", 0.1 );
		}
		if     ( SDLK_f == ke.keysym.sym )
		{
			if( isnormal ) dsan.attach( "motion" );
			else dsan.attach( "normal1" );
			isnormal ^= true;
		}
	}

}

/*FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF*\
|*|                                   main                                   |*|
\*FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF*/
void main()
{
	auto wnd = new MQOTest;
	scope( exit ) wnd.clear();
	wnd.mainLoop;
}

/*CCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCC*\
|*|                                DsanDrawer                                |*|
\*CCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCC*/
/**
 * Dさんを表示するだけのクラス。$(BR)
 * なんかダラダラ長いのでもうちょっと考えたい。
 */
class DsanDrawer
{
     //--------------------------------------------------------------------
	string vertex_shader =
	q{#version 420
		uniform mat4 world;
		uniform int[4] transform_id;
		uniform mat4[4] transform;
		in vec3 pos;
		in vec2 uv;
		in ivec4 mat;
		in vec4 influence;

		out vec2 f_texcoord;

		int searchIndex( int i )
		{
			if( transform_id[0] == i ) return 0;
			if( transform_id[1] == i ) return 1;
			if( transform_id[2] == i ) return 2;
			if( transform_id[3] == i ) return 3;
			return 4;
		}

		void main()
		{
			vec4 v = vec4( 0, 0, 0, 0 );
			vec4 p = vec4( pos, 1.0 );

			int i;
			i = searchIndex( mat[0] );
			if( i < 4 ) v += ( transform[ i ] * p ) * influence[0];

			i = searchIndex( mat[1] );
			if( i < 4 ) v += ( transform[ i ] * p) * influence[1];

			i = searchIndex( mat[2] );
			if( i < 4 ) v += ( transform[ i ] * p) * influence[2];

			i = searchIndex( mat[3] );
			if( i < 4 ) v += ( transform[ i ] * p) * influence[3];

			gl_Position = world * v;
			f_texcoord = uv;
		}
	};

     //--------------------------------------------------------------------
	string fragment_shader =
	q{#version 420
		uniform vec4 color;
		uniform int use_texture;
		uniform sampler2D texture1;
		in vec2 f_texcoord;

		layout( location = 0 ) out vec4 colorOut;

		void main()
		{
			if( 0 < use_texture ) colorOut = color * texture2D( texture1, f_texcoord );
			else colorOut = color;
		}
	};

    //--------------------------------------------------------------------
	Shader vs, fs;
	ShaderProgram prog;
	VertexArrayObject[] vao;

	Matrix4f* projlook;
	Matrix4f world;
	void delegate()[] _draws;
	GLuint world_loc, color_loc, use_tex_loc;
	Texture2DRGBA32[string] tex;
	
	this( Actor actor, ref Matrix4f projlook, string delegate(jstring) toUTF8 )
	{
		assert( 0 < actor.bsys.bones.length );
		vs = new Shader( GL_VERTEX_SHADER, vertex_shader );
		fs = new Shader( GL_FRAGMENT_SHADER, fragment_shader );
		prog = (new ShaderProgram(vs, fs )).link;
		world_loc = prog.world;
		color_loc = prog.color;
		use_tex_loc = prog.use_texture;

		vao = new VertexArrayObject[ actor.skins.length ];
		foreach( i, ref one ; vao ) one = new VertexArrayObject( prog, actor.skins[i] );

		foreach( bone ; actor.bsys.bones ) // ボーン
		{
			foreach( part ; bone.parts ) // レイヤー( == ObjectChunk )
			{
				foreach( face ; part.faces ) // マテリアル
				{
					auto d = vao[ part.vertex_id ].getDrawer!GL_TRIANGLES( face.index );

					bool use_tex = false;
					if( 0 < face.material.texture.length )
					{
						auto texfile = searchFile( toUTF8( face.material.texture ) );
						if( texfile !in tex ) tex[texfile] = loadTexture2DRGBA32( (texfile ~ "\0").ptr );
						d = drawSystem( d, prog, [ "texture1" : tex[texfile] ] );
						use_tex = true;
					}

					_draws ~= ( color, use_texture, draw, b0, bs )
					{
						return
						{
							prog[ "transform_id", 0 ] = b0.id;
							prog[ "transform", 0 ] = b0.transform;
							prog[ "transform_id", 1 ] = 4;
							prog[ "transform_id", 2 ] = 4;
							prog[ "transform_id", 3 ] = 4;
							switch( bs.length )
							{
								case 3:
									prog[ "transform_id", 3 ] = bs[2].id;
									prog[ "transform", 3 ] = bs[2].transform;
								case 2:
									prog[ "transform_id", 2 ] = bs[1].id;
									prog[ "transform", 2 ] = bs[1].transform;
								case 1:
									prog[ "transform_id", 1 ] = bs[0].id;
									prog[ "transform", 1 ] = bs[0].transform;
								default:
							}
							prog[ color_loc ] = color;
							prog[ use_tex_loc ] = use_texture ? 1 : 0;
							draw();
						};
					}( face.material.color, use_tex, d, bone, bone.neighbours );
				}
			}
		}
		this.projlook = &projlook;
		world = Matrix4f.identityMatrix();
	}

	void update( size_t interval )
	{
		world *= Matrix4f.rotateZXMatrix( interval * 0.001 );
	}

	void draw()
	{
		prog[ world_loc ] = (*projlook) * world;
		foreach( one ; _draws ) one();
	}

	void clear()
	{
		foreach( v ; vao ) v.clear;
		foreach( t ; tex ) t.clear;
		prog.clear;
		vs.clear;
		fs.clear;
	}
}

/*FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF*\
|*|                              drawBonesBBox                               |*|
\*FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF*/
void drawBonesBbox( ref Matrix4f world, Bone[] bones, OBBoxDrawer drawer, float line_width
                 , ref in Color4f color )
{
	foreach( bone ; bones )
	{
		Matrix4f mat = world * bone.currentGlobalize.toMatrix * Matrix4f.translateMatrix( -bone.centering )
		               * Matrix4f.scaleMatrix( bone.bbox.width2.x, bone.bbox.width2.y, bone.bbox.width2.z );
		drawer.draw( mat, line_width, color );
	}
}

/*CCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCC*\
|*|                               OBBoxDrawer                                |*|
\*CCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCC*/
class OBBoxDrawer
{
     //--------------------------------------------------------------------
	string vertex_shader =
	q{#version 420
		uniform mat4 world;
		in vec3 pos;

		void main() { gl_Position = world * vec4( pos, 1.0 ); }
	};

     //--------------------------------------------------------------------
	string fragment_shader =
	q{#version 420
		uniform vec4 color;
		layout( location = 0 ) out vec4 colorOut;

		void main() { colorOut = color; }
	};

     //--------------------------------------------------------------------
	Shader vs, fs;
	ShaderProgram prog;
	VertexArrayObject vao;

	void delegate( ref Matrix4f, float, ref in Color4f ) draw;
	GLuint world_loc, color_loc;

	struct V{ float[3] pos; this( float[3] p ... ){ this.pos[] = p; } }
	V[] vertex = [ V( 1, 1, 1), V( 1, 1, -1 ), V( -1, 1, -1 ), V( -1, 1, 1 )
	             , V( 1, -1, 1 ), V( 1, -1, -1 ), V( -1, -1, -1 ), V( -1, -1, 1 ) ];
	uint[] idx = [ 0, 1, 1, 2, 2, 3, 3, 0, 0, 4, 1, 5, 2, 6, 3, 7, 4, 5, 5, 6, 6, 7, 7, 4 ];

	this( ref Matrix4f projlook )
	{
		vs = new Shader( GL_VERTEX_SHADER, vertex_shader );
		fs = new Shader( GL_FRAGMENT_SHADER, fragment_shader );

		prog = (new ShaderProgram( vs, fs )).link;
		world_loc = prog.world;
		color_loc = prog.color;

		vao = new VertexArrayObject( prog, vertex );
		draw = ( void delegate() d, ref Matrix4f pl )
		{ return ( ref Matrix4f world, float line_width, ref in Color4f color ){
			glLineWidth( line_width );
			prog[ color_loc ] = color;
			prog[ world_loc ] = projlook * world;
			d();
		}; }( vao.getDrawer!GL_LINES( idx ), projlook );
	}

	void clear()
	{
		vao.clear;
		prog.clear;
		vs.clear;
		fs.clear;
	}
}

/*CCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCC*\
|*|                                OBBTestBox                                |*|
\*CCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCC*/
class OBBTestBox
{
	OBBox bbox;

	Vector3f linear;
	Quaternionf angular;
	Vector3f velocity;
	Quaternionf moment;
	int life;
	Color4f color;

	this( ) { reset(); color = Color4f( 1, 0, 0, 1 ); }

	void reset()
	{
		linear = Vector3f( uniform( -150f, 150f ), -150, 0 );
		angular = Quaternionf();
		bbox.width2 = Vector3f( uniform( 10f, 50f ), uniform( 10f, 50f ), uniform( 10f, 50f ) );
		velocity = Vector3f( 0, uniform( 50f, 100f ), 0 );
		moment = Quaternionf.rotateQuaternion( uniform( -4f, 4f ), Vector3f( uniform( -1, 1 ), uniform( -1, 1 )
		                                                                   , uniform( -1, 1 ) ).normalizedVector );
		bbox.localize = Tranf( linear, angular );
		life = 10000;
	}

	void update( size_t interval )
	{
		Quaternionf q0;
		float r = (cast(float)interval) * 0.001;
		linear += velocity * r;
		angular = interpolateLinear( q0, r, moment ) * angular;
		bbox.localize = Tranf( linear, angular );
		life -= interval;
		if( life < 0 ) reset();
	}

	void draw( OBBoxDrawer drawer, ref Matrix4f world )
	{
		Matrix4f mat = world * Matrix4f.translateMatrix( -linear ) * angular.conjugate.toMatrix
		               * Matrix4f.scaleMatrix( bbox.width2.x, bbox.width2.y, bbox.width2.z );
		drawer.draw( mat, 1.5, color );
	}
}

/*CCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCC*\
|*|                                 WazaList                                 |*|
\*CCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCC*/
// 左下の技表を表示するためだけのクラス。
class WazaList
{
	static string vertex_shader =
	q{ #version 420

		in vec2 position;
		in vec2 texcoord;

		out vec2 f_texcoord;

		void main()
		{
			gl_Position = vec4( position, 0.0, 1.0 );
			f_texcoord = texcoord;
		}
	};

	static string fragment_shader =
	q{ #version 420

		in vec2 f_texcoord;
		uniform sampler2D texture1;

		layout( location = 0 ) out vec4 colorOut;

		void main()
		{
			colorOut = texture2D( texture1, f_texcoord );
		}
	};

	struct Vertex
	{
		float[2] position;
		float[2] texcoord;
		this( float[4] p ... ){ position[] = p[ 0 .. 2 ]; texcoord = p[ 2 .. 4 ]; }
	}
	Vertex[] vertex = [ Vertex( -1, -1,  0, 1 ), Vertex( -0.3, -1, 1, 1 )
	                  , Vertex( -0.3, -0.3, 1, 0 ), Vertex( -1, -0.3, 0, 0 ) ];
	ubyte[] index = [ 0, 1, 2, 3 ];

	Shader vs, fs;
	ShaderProgram prog;
	VertexArrayObject vao;
	Texture2DRGBA32 tex;
	void delegate() draw;

	this( const(char)* texfile )
	{
		vs = new Shader( GL_VERTEX_SHADER, vertex_shader );
		fs = new Shader( GL_FRAGMENT_SHADER, fragment_shader );
		prog = (new ShaderProgram( vs, fs )).link;

		vao = new VertexArrayObject( prog, vertex );

		tex = loadTexture2DRGBA32( texfile );

		draw = drawSystem( vao.getDrawer!GL_TRIANGLE_FAN( index ), prog, [ "texture1" : tex ] );
	}

	void clear()
	{
		tex.clear();
		vao.clear();
		prog.clear();
		vs.clear();
		fs.clear();
	}
}