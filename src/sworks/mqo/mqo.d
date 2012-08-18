/** Metasequoia モデルのファイルフォーマット .mqo を読み込む。
 * Version:      0.0012(dmd2.060)
 * Date:         2012-Aug-17 00:12:50
 * Authors:      KUMA
 * License:      CC0
 */
module sworks.mqo.mqo;

import std.algorithm, std.conv, std.exception, std.file, std.regex;

public import sworks.compo.util.matrix;
import sworks.mqo.parser_core;
public import sworks.mqo.misc;

/*CCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCC*\
|*|                                 MQObject                                 |*|
\*CCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCC*/
/**
 * .mqo を表現する最外のオブジェクト
 * メンバがそれぞれのチャンクを表現している。
 *
 * Bugs:
 * MQObject のメンバには全て、引数無しのコンストラクタが必要
 */
class MQObject
{
	/**
	 * <del>.mqo ファイルのヘッダにヒットする正規表現</del>$(BR)
	 * <del>Captures[1] にバージョン文字列が入るようにしてある。</del>( ver0.0011以降 )
	 * ファイル先頭からヴァージョン文字列直前までの文字列を入れておく。$(BR)
	 * BOM はついていないものと仮定する。$(BR)
	 * コンパイル時に std.regex が使えないからだきょった orz...$(BR)
	 */
//	enum HEADER = `^Metasequoia\s+Document[\r\n]+Format\s+Text\s+Ver\s+(1\.\d)[\r\n]+`;
	enum HEADER = "Metasequoia Document\r\nFormat Text Ver";

	string version_string; /// メタセコイアファイルフォーマットのバージョン。(現在 1.0 )
	SceneChunk scene; /// Scene チャンク
	Material[] material; /// Material チャンク
	ObjectChunk[jstring] object; /// Object チャンク

	@disable void* noise_chunk; /// not supported.
	@disable string include_xml; /// not supported.
	@disable string back_image; /// not supported.
	@disable string blob; /// not supported.

	/**
	 * OpenGL用に最適化$(BR)
	 * 現在、
	 * <ul>
	 *   <li> BVertexチャンク を Vertexチャンクに読み込み</li>
	 *   <li> Face の表裏を反転(メタセコイアとOpenGLでは表裏が逆)</li>
	 *   <li> mirror を展開。</li>
	 * </ul>
	 * をしている。
	 * Bugs:
	 * 表面を継げての mirror 展開にはまだ対応していません。
	 */
	void optimizeForGL()
	{
		foreach( one ; object )
		{
			one.checkBVertex();
			one.reverseFaces();
			one.expandMirror();
		}
	}
}

/*CCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCC*\
|*|                                SceneChunk                                |*|
\*CCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCC*/
/// Scene チャンクの表現
class SceneChunk
{
	Vector3f pos; /// 本家ページでは詳細が省略されている
	Vector3f lookat; /// ditto
	float head; /// ditto
	float pich; /// ditto
	int ortho; /// ditto
	float zoom2; /// ditto
	Color3f amb; /// ditto
}

/*CCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCC*\
|*|                                 Material                                 |*|
\*CCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCC*/
/// Material チャンク内のそれぞれの Material の表現
class Material : IOwnParser
{
	jstring name; /// 材質名
	/**
	 * シェーダ$(BR)
	 * 0 Classic$(BR)
	 * 1 Constant$(BR)
	 * 2 Lambert$(BR)
	 * 3 Phong$(BR)
	 * 4 Blinn$(BR)
	 */
	int shader;
	/**
	 * 頂点カラー$(BR)
	 * 0 なし$(BR)
	 * 1 あり$(BR)
	 */
	int vcol;
	Color4f col; /// 色 ( R G B A ) 各色 [ 0, 1 ]
	float dif; /// 拡散光 [ 0, 1 ]
	float amb; /// 周囲光 [ 0, 1 ]
	float emi; /// 自己照明 [ 0, 1 ]
	float spc; /// 反射光 [ 0, 1 ]
	float power; /// 反射光の強さ。 [ 0, 100 ]
	jstring tex; /// 模様マッピング名 ( 相対パス )
	jstring aplane; /// 透明マッピング名 ( 相対パス )
	jstring bump; /// 凹凸マッピング名 ( 相対パス )
	/**
	 * マッピング方式$(BR)
	 * 0 UV
	 * 1 平面
	 * 2 円筒
	 * 3 球
	 */
	int proj_type;
	Vector3f proj_pos; /// 投影位置 ( x y z )
	Vector3f proj_scale; /// 投影拡大率 ( x y z )
	Vector3f proj_angle; /// 投影角度 ( H P B ) [ -180, 180 ]

	// Material は書式が例外的なので特別なパーサを持つ。sworks.mqo.parser.chomp より呼び出される。
	bool parser( ref Token token )
	{
		if( Token.TYPE.JSTRING )
		{
			if( 0 < name.length ) return false; // -> このインスタンスでの処理を終わる。
			token.chomp( name );
		}
		else token.popFront;
		return true; // -> 処理を継続 ( cell の続きで chomp を再帰呼び出し )
	}

	/**
	 * Mikoto 用。材質名を展開して返す。$(BR)
	 * name が、"腕[]" みたいになっていた場合、x が正の時は "腕[L]"に、x が負の場合は "腕[R]" に展開する。$(BR)
	 * name が、"体" みたいな時はそのまま返す。$(BR)
	 */
	jstring getName( float x = 0.0 )
	{
		auto n = name;
		if( n.endsWith( "[]".j ) ) n = n[ 0 .. $ - 1 ] ~ ( 0 < x ? "L".j : "R".j ) ~ ("]".j);
		return n;
	}

}

/*CCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCC*\
|*|                               ObjectChunk                                |*|
\*CCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCC*/
/// オブジェクトチャンク
class ObjectChunk : INamable
{
	jstring _name;
	jstring name() @property const { return _name; }
	void name( jstring n ) @property { _name = n; }

	int depth; /// 階層の深さ。ルート直下を 0 として深くなるごとに +1。
	/**
	 * オブジェクトパネル上の階層の折りたたみ。$(BR)
	 * 0 通常表示$(BR)
	 * 1 子オブジェクトを折りたたんで非表示$(BR)
	 */
	int folding;
	Vector3f scale; /// ローカル座標の拡大率 ( x y z )
	Vector3f rotation; /// ローカル座標の回転角 ( H P B )
	Vector3f translation; /// ローカル座標の平行移動量 ( x y z )
	/**
	 * 曲面の形式$(BR)
	 * 0 平面(曲面指定をしない)$(BR)
	 * 1 曲面タイプ1 ( スプライン Type1 )$(BR)
	 * 2 曲面タイプ2 ( スプライン Type2 )$(BR)
	 * 3 Catmull-Clark ( Metasequoia Ver2.2以降 )
	 * Bugs:
	 * 0 以外対応してません。
	 */
	int patch;
	/**
	 * 曲面の分割数$(BR)
	 * patch = 1 .. 3 の時[ 1, 16 ]$(BR)
	 * patch = 3 の時 [ 1, 4 ] ( Catmull-Clarkの場合、再帰分割数を示すため)$(BR)
	 */
	int segment;
	/**
	 * 表示、非表示$(BR)
	 * 0 非表示$(BR)
	 * 15 表示$(BR)
	 */
	int visible;
	/**
	 * オブジェクトの固定$(BR)
	 * 0 編集可能$(BR)
	 * 1 編集禁止$(BR)
	 */
	int locking;
	/**
	 * シェーディング$(BR)
	 * 0 フラットシェーディング$(BR)
	 * 1 グローシェーディング$(BR)
	 */
	int shading;
	float facet; /// スムージング角度 [ 0, 180 ]
	Color3f color; /// 色 ( R G B ) それぞれ [ 0, 1 ]
	/**
	 * 辺の色タイプ$(BR)
	 * 0 環境設定での色を使用$(BR)
	 * 1 オブジェクト固有の色を使用$(BR)
	 */
	int color_type;
	/**
	 * 鏡面のタイプ$(BR)
	 * 0 なし$(BR)
	 * 1 左右を分離$(BR)
	 * 2 左右を接続(対応してません。)$(BR)
	 */
	int mirror;
	/**
	 * 鏡面の適用軸$(BR)
	 * 1 X軸$(BR)
	 * 2 Y軸$(BR)
	 * 3 Z軸$(BR)
	 */
	int mirror_axis;
	float mirror_dis; /// 接続距離 [ 0, float.max ]
	/**
	 * 回転体のタイプ$(BR)
	 * 0 なし$(BR)
	 * 3 両面(対応してません。)$(BR)
	 */
	int lathe;
	/**
	 * 回転体の軸$(BR)
	 * 0 X軸$(BR)
	 * 1 Y軸$(BR)
	 * 2 Z軸$(BR)
	 */
	int lathe_axis;
	int lathe_seg; /// 回転体の分割数 [ 3, int.max ]
	Vector3f[] vertex; /// Vertex チャンク
	VertexAttrChunk vertexattr; /// Metasequoia Ver2.2以降
	Face[] face; /// Face チャンク

	BVertexChunk bvertex;

	/// BVertex をチェックし、もし存在するなら vertex チャンクに Shallow Copy する。
	void checkBVertex()
	{
		if( null !is bvertex && 0 == vertex.length )
			vertex = bvertex.vector;
	}

	/**
	 * 表裏を反転させる。$(BR)
	 * Bugs:
	 * 実際の表裏を考慮しない。なんでもかんでも逆にする。
	 */
	void reverseFaces()
	{
		foreach( one ; face ) one.reverse;
	}

	/**
	 * ミラー処理を展開する。
	 *
	 * Bugs:
	 * 2 == mirror の「左右を接続」にはまだ対応していない。
	 */
	void expandMirror()
	{
		if( 0 < mirror )
		{
			if( 0 < (1 & mirror_axis) )
			{
				auto iv = vertex.dup;
				foreach( ref one ; iv ) one.x *= -1;
				auto iface = new Face[ face.length ];
				foreach( i, ref one ; iface )
				{
					one = face[i].dup;
					one.V[] += vertex.length;
					one.reverse;
				}
				vertex ~= iv;
				face ~= iface;
			}
			if( 0 < (2 & mirror_axis) )
			{
				auto iv = vertex.dup;
				foreach( ref one ; iv ) one.y *= -1;
				auto iface = new Face[ face.length ];
				foreach( i, ref one ; iface )
				{
					one = face[i].dup;
					one.V[] += vertex.length;
					one.reverse;
				}
				vertex ~= iv;
				face ~= iface;
			}
			if( 0 < (4 & mirror_axis) )
			{
				auto iv = vertex.dup;
				foreach( ref one ; iv ) one.z *= -1;
				auto iface = new Face[ face.length ];
				foreach( i, ref one ; iface )
				{
					one = face[i].dup;
					one.V[] += vertex.length;
					one.reverse;
				}
				vertex ~= iv;
				face ~= iface;
			}
			mirror = 0;
		}
	}


	// 凸の多角形を TRIANGLE_FAN とみなして三角形に分割
	void expandPolygon()
	{
		Face[] aface;
		foreach( f ; face )
		{
			for( size_t i = 3 ; i < f.V.length ; i++ )
			{
				aface ~= f.subTriangleFan( i - 2 );
			}
			f.length = 3;
		}
		face ~= aface;
	}

}

/*CCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCC*\
|*|                               BVertexChunk                               |*|
\*CCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCC*/
/// BVertex チャンク
class BVertexChunk
{
	int length;
	Vector3f[] vector;
	WeitChunk[] weit;
	ColorChunk[] color;
}

/*CCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCC*\
|*|                             VertexAttrChunk                              |*|
\*CCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCC*/
/// VertexAttr チャンク
class VertexAttrChunk
{
	WeitChunk[] weit;
	ColorChunk[] color;
}

/// Face チャンク内のそれぞれの Face
class Face : ILength, IOwnParser
{
	uint[] V;
	int M;
	UVf[] UV;
	uint[] COL;

	uint length() const @property { return V.length; }
	void length( uint l ) @property
	{
		V.length = l;
		UV.length = l;
		COL.length = l;
	}


	/// Face チャンク内は書式が例外的なので専用のパーサを持つ。
	bool parser( ref Token  token )
	{
		if( Token.TYPE.INT == token.type ) return false;
		else token.popFront;
		return true;
	}

	/// 表裏を逆にする。Metasequoia は OpenGL とは表裏が逆。
	void reverse()
	{
		V.reverse;
		UV.reverse;
		COL.reverse;
	}

	/// 複製する。
	Face dup() const
	{
		auto f = new Face;
		f.V = V.dup;
		f.M = M;
		f.UV = UV.dup;
		f.COL = COL.dup;
		return f;
	}

	/// TRIANGLE_FAN(と仮定して) i 個目の TRIANGLE を抜き出す。
	Face subTriangleFan( uint i ) const
	{
		auto f = new Face;
		f.length = 3;
		f.M = M;

		f.V[0] = V[0];
		f.UV[0] = UV[0];
		f.COL[0] = COL[0];
		f.V[ 1 .. 3 ] = V[ i + 1 .. i + 3 ];
		f.UV[ 1 .. 3 ] = UV[ i + 1 .. i + 3 ];
		f.COL[ 1 .. 3 ] = COL[ i + 1 .. i + 3 ];
		return f;
	}
}



/*SSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSS*\
|*|                               WeightChunk                                |*|
\*SSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSS*/
/// Weit チャンク // not supported
struct WeitChunk
{
	int index;
	float value;
}

/*SSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSS*\
|*|                                ColorChunk                                |*|
\*SSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSS*/
/// Color チャンク // not supported
struct ColorChunk
{
	int index;
	uint value;
}

////////////////////XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX\\\\\\\\\\\\\\\\\\\\
debug(mqo)
{
import std.stdio;
import sworks.mqo.parser;
import sworks.compo.util.dump_members;

void main()
{
//	auto cc = new CellObject( new CoreCell( new CachedFile( "dsan\\DさんMove.mks" ), &toUTF8 ) );
//	auto mqo = load!MQObject( "dsan\\Dさん.mqo" );
	auto mqo = load!MQObject( "dsan\\Dさん.mqo" );

	writeln( mqo.dump_members );
}
}

debug(ctmqo){
import std.stdio;
import sworks.mqo.ct_parser;
import sworks.compo.util.dump_members;


enum mqo = load!( MQObject, "dsan.mqo" ).dump_members;

void main()
{
writeln( mqo );
//	auto obj = load!MQObject( "test1.mqo" );
//	writeln( obj.dump_members );
}
}