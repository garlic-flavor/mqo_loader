/** DerelictSDL2 と一緒に DerelictGL[3] を使う。
 * Version:      0.0014(dmd2.062)
 * Date:         2013-Apr-06 01:08:29
 * Authors:      KUMA
 * License:      CC0
 */
module sworks.compo.sdl.gl;

import std.exception;
public import sworks.compo.gl.util;
public import sworks.compo.gl.glsl;
public import sworks.compo.gl.texture_2drgba32;
public import sworks.compo.sdl.util;
public import sworks.compo.sdl.image;

/// テクスチャ読み込み。
Texture2DRGBA32 loadTexture2DRGBA32( const(char)* filename )
{
	auto s = loadImageRGBA32( filename );
	scope( exit ) SDL_FreeSurface( s );
	return new Texture2DRGBA32( s.w, s.h, s.pixels );
}

/// テクスチャ付き描画に。
/// $(D_PARAM draw) に関しては sworks.compo.gl.glsl を参照のこと。
void delegate() drawSystem( void delegate() draw, ShaderProgram program, Texture2DRGBA32[string] tex )
{
	struct _Tex{ GLuint id; GLuint location; };
	_Tex[] textures;
	foreach( key, one ; tex )
	{
		textures ~= _Tex( one.id, program[ key ] );
	}

	return
	{
		foreach( i, one ; textures )
		{
			glActiveTexture( GL_TEXTURE0 + i );
			glBindTexture( GL_TEXTURE_2D, one.id );
			program[ one.location ] = i;
		}
		draw();
		foreach( i, one ; textures )
		{
			glActiveTexture( GL_TEXTURE0 + i );
			glBindTexture( GL_TEXTURE_2D, 0 );
		}
	};
}
////////////////////XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX\\\\\\\\\\\\\\\\\\\\
debug(sdl_gl):
import std.math;
import sworks.compo.gl.glsl;
import sworks.compo.util.matrix;
import sworks.compo.sdl.image;

string vertex_shader_content =
q{
	#version 420

	uniform mat4 transform;
	in vec3 position;
	in vec3 v_color;
	in vec2 texcoord;

	out vec2 f_texcoord;
	out vec3 color;

	void main()
	{
		gl_Position = transform * vec4( position, 1.0 );
		color = v_color;
		f_texcoord = texcoord;
	}
};

string fragment_shader_content =
q{
	#version 420

	in vec2 f_texcoord;
	uniform float fade;
	uniform sampler2D mytexture;

	in vec3 color;
	layout(location = 0 ) out vec4 colorOut;

	void main()
	{
//		colorOut = vec4( color, floor( mod( gl_FragCoord.y, 2.0 ) ) * fade );
		colorOut = texture2D(  mytexture, f_texcoord );
		colorOut[3] = floor( mod( gl_FragCoord.y, 2.0 ) ) * fade;
	}
};

struct Vertex
{
	float[3] position;
	float[3] v_color;
	float[2] texcoord;
	this( float[8] p ... ){ position[] = p[ 0 .. 3 ]; v_color[] = p[ 3 .. 6 ]; texcoord[] = p[ 6 .. 8 ]; }
}

Vertex[] pos = [ Vertex( -1.0, -1.0,  1.0,   1.0, 0.0, 0.0,   0.0, 0.0 )
               , Vertex(  1.0, -1.0,  1.0,   0.0, 1.0, 0.0,   1.0, 0.0 )
               , Vertex(  1.0,  1.0,  1.0,   0.0, 0.0, 1.0,   1.0, 1.0 )
               , Vertex( -1.0,  1.0,  1.0,   1.0, 1.0, 1.0,   0.0, 1.0 )

               , Vertex( -1.0, -1.0, -1.0,   1.0, 0.0, 0.0,   0.0, 0.0 )
               , Vertex(  1.0, -1.0, -1.0,   0.0, 1.0, 0.0,   1.0, 0.0 )
               , Vertex(  1.0,  1.0, -1.0,   0.0, 0.0, 1.0,   1.0, 1.0 )
               , Vertex( -1.0,  1.0, -1.0,   1.0, 1.0, 1.0,   0.0, 1.0 ) ];

uint[] idx = [ 0, 1, 2,  2, 3, 0,   1, 5, 6,  6, 2, 1,   7, 6, 5,  5, 4, 7,   4, 0, 3,  3, 7, 4
             , 4, 5, 1,  1, 0, 4,   3, 2, 6,  6, 7, 3 ];

scope class SDLTest
{ mixin SDLIdleWindowMix!() SWM;

	Shader vShader, fShader;
	ShaderProgram program;
	VertexArrayObject vao;
	GLuint fade_loc;
	GLuint trans_loc;

	Matrix4f projlook;
	Matrix4f world;

	Texture2DRGBA32 tex1;

	void delegate() drawFunc;

	this()
	{
		SWM.ctor( SDL_INIT_VIDEO, "hello SDL",  640, 480, SDL_WINDOW_OPENGL, 30
		        , getImageInitializer( IMG_INIT_JPG )
		        , getGLInitializer( false, 16, 8, 8, 8, 8 ) );
		DerelictGL3.reload();
		enforce( GLVersion.GL33 <= DerelictGL3.loadedVersion, "OpenGL 3.3 not supported." );

		vShader = new Shader( GL_VERTEX_SHADER, vertex_shader_content );
		fShader = new Shader( GL_FRAGMENT_SHADER, fragment_shader_content );
		program = (new ShaderProgram( vShader, fShader)).link;
		fade_loc = program.fade;

		vao = new VertexArrayObject( program );
		vao.vertex = pos;
		vao.index!GL_TRIANGLES = idx;
		
		projlook = Matrix4f.perspectiveMatrix( 45, 640.0 / 480.0, 1, 100 );
		projlook *= Matrix4f.lookAtMatrix( [ 0, 3, 5 ], [ 0.0, 0.0, 0.0 ], [ 0.0, 1.0 , 0.0 ] );
		trans_loc = program.transform;

		program[ trans_loc ] = projlook;

		auto s1 = loadImageRGBA32( "img\\tex1.jpg" );
		scope( exit ) SDL_FreeSurface( s1 );
		tex1 = new Texture2DRGBA32( s1.w, s1.h, s1.pixels );

		drawFunc = drawSystem( vao.drawElements, program, [ "mytexture" : tex1 ] );

		glClearColor( 0, 0.7, 0, 0 );
		glViewport( 0, 0, 640, 480 );
		glEnable( GL_BLEND );
		glBlendFunc( GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA );
		glEnable( GL_DEPTH_TEST );
		glDepthFunc( GL_LESS );
		glEnable( GL_CULL_FACE );
		glCullFace( GL_BACK );
		

		checkNoError("noerror");
	}

	~this()
	{
		vao.clear;
		program.clear;
		fShader.clear;
		vShader.clear;
		tex1.clear;
		SWM.dtor;
	}

	void update( size_t interval )
	{
		world *= Matrix4f.rotateZXMatrix( (cast(float)interval) * 0.001 );
		Matrix4f mat = projlook * world;
		program[ trans_loc ] = mat;
		program[ fade_loc ] = cast(float)sin( SDL_GetTicks() / 1000.0 * ( 2 * PI ) / 5 ) / 2 + 0.5;

	}

	void draw()
	{
		glClear( GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT );

		drawFunc();

		SDL_GL_SwapWindow( window );
	}
}


void main()
{
	scope auto sdltest = new SDLTest();
	sdltest.mainLoop;
}
