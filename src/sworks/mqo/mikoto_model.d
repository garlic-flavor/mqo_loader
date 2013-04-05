/** mqo.d に対応する。Metasequoia → Mikoto で使い安い形式に。
 * Version:      0.0014(dmd2.062)
 * Date:         2013-Apr-06 01:08:29
 * Authors:      KUMA
 * License:      CC0
 */
module sworks.mqo.mikoto_model;

import std.algorithm;
debug import std.conv;
import sworks.mqo.misc;
import sworks.mqo.mqo;

/*CCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCC*\
|*|                               MikotoModel                                |*|
\*CCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCC*/
/// MQObject に対応している。
class MikotoModel
{
	MikotoSkin[] skins; /// レイヤー毎に分類されている。
	MikotoMaterial[] materials; /// 材質
}

/*SSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSS*\
|*|                                MikotoSkin                                |*|
\*SSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSS*/
/// 一つの ObjectChunk に対応。ソフト(Metasequoia)上では一つのレイヤに対応している。んだと思う。多分。
struct MikotoSkin
{
	jstring name; /// スキンの名前
	Vector3f[] vertex; /// スキンを構成する頂点
	MikotoFace[] faces; /// マテリアル毎に分類されたインデックス値
	MikotoLine[] lines; /// ditto
}

/*SSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSS*\
|*|                                MikotoFace                                |*|
\*SSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSS*/
/**
 * GL_TRIANGLES で形成されている。
 */
struct MikotoFace
{
	int material_id; /// マテリアルを参照するインデッス値
	uint[] index; /// GL_TRIANGLES
	UVf[] uv; /// テクスチャ座標
	alias index this;

	///
	this( int m ){ this.material_id = m; }
	/**
	 * ポリゴンの表裏を入れ替えながら、TRIANGLE_FAN を TRIANGLES に展開しながら、追加
	 * ポリラインはそのまま追加
	 */
	void append( const(uint)[] f, const(UVf)[] t )
	{
		if     ( 3 <= f.length )
		{
			auto pl = index.length;
			index.length = index.length + ( ( f.length - 2 ) * 3 );
			if( 0 < t.length ) uv.length = index.length;
			for( size_t i = 3 ; i <= f.length ; i++ )
			{
				index[ pl + ( i - 3 ) * 3 ] = f[ 0 ];
				index[ pl + ( i - 3 ) * 3 + 1 ] = f[ i - 1 ];
				index[ pl + ( i - 3 ) * 3 + 2 ] = f[ i - 2 ];
				if( 0 < t.length )
				{
					uv[ pl + ( i - 3 ) * 3 ] = t[ 0 ];
					uv[ pl + ( i - 3 ) * 3 + 1 ] = t[ i - 1 ];
					uv[ pl + ( i - 3 ) * 3 + 2 ] = t[ i - 2 ];
				}
			}
		}
	}
}

/*SSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSS*\
|*|                                MikotoLine                                |*|
\*SSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSS*/
/// ポリラインのみで形成されている。
struct MikotoLine
{
	int material_id;
	uint[] index; /// GL_LINES
	alias index this;

	this( int m ){ this.material_id = m; }
}

/*SSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSS*\
|*|                              MikotoMaterial                              |*|
\*SSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSS*/
/**
 * ToDo:
 *   今後、メンバを増やしていく予定
 */
class MikotoMaterial
{
	jstring name;   /// 名前
	Color4f color; /// 色
	jstring texture; /// テクスチャファイル名(※ SHIFT-JIS 注意)

	this( in ref Material m ){ this.name = m.name; this.color = m.col; this.texture = m.tex; }
	this( jstring n, in ref Material m ){ this.name = n; this.color = m.col; this.texture = m.tex; }
	this( jstring n, Color4f c, jstring tex ){ this.name = n; this.color = c; this.texture = tex; }
}

/*FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF*\
|*|                             mqoToMikotoModel                             |*|
\*FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF*/
/// Metasequoia モデルを Mikoto で扱い安いように変形させる。
MikotoModel mqoToMikotoModel( MQObject mqo )
{
	auto mm = new MikotoModel;

	auto mms = mqo.material.buildMikotoMaterialsStore!true();
	mm.materials = mms.materials;
	size_t i = 0;
	mm.skins = new MikotoSkin[ mqo.object.length ];
	foreach( obj ; mqo.object ) mm.skins[i++] = obj.objectChunkToMikotoSkin!true( mms );
	return mm;
}


//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\
//\\                                                                        //\\
//\\                                private                                 //\\
//\\                                                                        //\\
//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\
/*SSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSS*\
|*|                           MikotoMaterialsStore                           |*|
\*SSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSS*/
// マテリアルのインデックス値によるマッチング
// [L]、[R] とかもこれで解決する。
private struct MikotoMaterialsStore
{
	MikotoMaterial[] materials;
	int[int] matching;
}

/*FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF*\
|*|                        buildMikotoMaterialsStore                         |*|
\*FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF*/
private MikotoMaterialsStore buildMikotoMaterialsStore( bool DIVIDE_LR = false )( Material[] materials )
{
	MikotoMaterialsStore mms;

	if( 0 == materials.length )
	{
		mms.materials ~= new MikotoMaterial( "default".j, Color4f( 1, 1, 1, 1 ), "".j );
		mms.matching[0] = 0;
	}
	else
	{
		size_t count = materials.length;
		static if( DIVIDE_LR )
			for( size_t i ; i < materials.length ; i++ ) if( materials[i].name.endsWith( "[]".j ) ) count++;

		mms.materials = new MikotoMaterial[ count ];
		size_t pos = materials.length;

		for( size_t i = 0 ; i < materials.length ; i++ )
		{
			mms.matching[i] = i;
			mms.materials[i] = new MikotoMaterial( materials[i] );
			static if( DIVIDE_LR )
			{
				if( materials[i].name.endsWith("[]".j) )
				{
					mms.materials[i].name = materials[i].name[ 0 .. $-2 ] ~ "[L]".j;
					mms.matching[ -i-1 ] = pos;
					mms.materials[ pos ] = new MikotoMaterial( materials[i].name[ 0 .. $-2 ] ~ "[R]".j, materials[i] );
					pos++;
				}
				else
					mms.matching[ -i-1 ] = i;
			}
		}
	}
	return mms;
}

/*FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF*\
|*|                         objectChunkToMikotoSkin                          |*|
\*FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF*/
private MikotoSkin objectChunkToMikotoSkin( bool DIVIDE_LR = false )( ObjectChunk object
                                                                    , MikotoMaterialsStore mms )
{
	MikotoSkin skin;
	skin.name = object.name;
	skin.vertex = object.vertex;

	MikotoFace[int] faces;
	MikotoLine[int] lines;
	foreach( one ; object.face )
	{
		int m;
		if( DIVIDE_LR && skin.vertex[one.V[0]].x < 0 ) m = mms.matching[ -one.M-1 ];
		else m = mms.matching[ one.M ];

		if     ( 3 <= one.V.length )
		{
			if( m !in faces ) faces[ m ] = MikotoFace( m );
			faces[ m ].append( one.V, one.UV );
		}
		else
		{
			if( m !in lines ) lines[ m ] = MikotoLine( m );
			lines[ m ] ~= one.V;
		}
	}

	skin.faces = faces.values;
	skin.lines = lines.values;
	return skin;
}

////////////////////XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX\\\\\\\\\\\\\\\\\\\\
debug(mikoto_model):
import std.stdio;
import sworks.mqo.parser;
import sworks.mqo.mqo;
import sworks.compo.util.dump_members;

void main()
{
	auto mqo = load!MQObject( "dsan\\Dさん.mqo" );
	auto mm = mqoToMikotoModel( mqo );

	foreach( mat ; mm.materials )
		writeln( mat.name.c );
}