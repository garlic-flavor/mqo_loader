/** MikotoModel を動かす為にボーンを準備する。
 * Version:      0.0013(dmd2.060)
 * Date:         2012-Aug-18 21:27:11
 * Authors:      KUMA
 * License:      CC0
 */
module sworks.mqo.bone_system;

import std.algorithm;
import sworks.compo.util.matrix;
import sworks.mqo.misc;
import sworks.mqo.mikoto_model;
debug import std.stdio, sworks.compo.util.dump_members;

/*SSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSS*\
|*|                                 BoneSet                                  |*|
\*SSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSS*/
/**
 * ボーンの名前(マテリアル名)と BoneSystem.bones でのインデックス値を紐付けするための一時オブジェクト。$(BR)
 * MikotoMotion のモーションを適用する際に参照される。$(BR)
 */
struct BoneSet
{
	BoneSystem bsys; /// 対象となる BoneSystem
	int[jstring] bone_id; /// マテリアル名 -&gt; インデックス
	/**
	 * bsys のルートボーンとその兄弟ボーンの名前を格納している。$(BR)
	 * モーション適用時、ルートボーンのみは平行移動するが、
	 * mkm ファイル内で兄弟ボーンの内どれが最上位とされているのか不明の為、全て列挙しておく。$(BR)
	 */
	jstring[] roots;
}

/*CCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCC*\
|*|                                BoneSystem                                |*|
\*CCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCC*/
/**
 * あるルートボーンとその子ボーンを管理する。$(BR)
 *
 * Bugs:
 *   頂点情報は、BoneSystem が管理している。(なんとなく違和感があるので変えるかも。)$(BR)
 *   Bone 下にスキンのインデックス、マテリアル情報も持たせている。
 */
class BoneSystem
{
	Bone root; /// 最上位のボーン

	SdefVertex[][] skins; /// bones で使われる全スキン。由来する ObjectChunk 毎に分類してある。
	Bone[] bones; /// このシステムに含まれる全てのボーン

	TranslateMotion world_translate; /// ローカル座標の平行移動運動
	RotateMotion world_rotate; /// ローカル座標の回転移動運動
	TranslateMotion root_translate; /// ルートのみ平行移動がある。
	Tranf root_world; /// ローカル座標の変換用

	/**
	 * Params:
	 *   bones = bones[0] がルートとする。
	 */
	this( Bone[] bones )
	{
		assert( 0 < bones.length );
		this.bones = bones;
		this.root = bones[0];
	}

	/// システムの変換行列を更新する。
	void update( float f )
	{
		root_world.loadIdentity;
		if( null !is world_translate ) root_world.translation = world_translate[f];
		if( null !is world_rotate ) root_world.rotation = world_rotate[f];
		if( null !is root_translate ) root_world += root_translate[f];

		root.update( f, root_world );
	}

}

/*CCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCC*\
|*|                                   Bone                                   |*|
\*CCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCC*/
/**
 * Mikoto のボーン。斜辺の対角が原点。$(BR)
 * 第二長辺が、Z軸正の向き。$(BR)
 * 最短辺と第二長辺の外積が X軸正の向きになっていると思われる。たぶん。$(BR)
 *
 * Bugs:
 *   現在スキンのインデックス値も保持しているが、なんとなく違和感があるので変えるかも。$(BR)
 */
class Bone
{
	int id; /// 0 がルートとなる、ボーンの ID。BoneSystem.bones のインデックス値。
	Bone parent; /// 親ボーン。
	Bone[] children; /// 子ボーン。
	Bone big_brother; /// 兄ボーン
	Bone little_brother; /// 弟ボーン

	Tranf localize; /// 一般ワールド座標 -&gt; origin を原点とするローカル座標への変換
	Vector3f globalize; /// ローカル座標 -&gt; 一つ上のボーンのローカル座標へ。
	Tranf currentGlobalize; /// アニメーション用にアップデートされる。
	/**
	 * 変換行列の最終的な変形結果が格納される。$(BR)
	 * シェーダなどから、これを参照する。
	 */
	Matrix4f transform;

	/**
	 * 現在適用中のモーション。ルートボーン以外は平行移動しない。$(BR)
	 * ボーンの先端(ローカル座標のZ軸正の向き)がワールド座標の Z軸正の向きと一致する位置からの回転を示している。
	 */
	RotateMotion motion;

	OBBox bbox; /// 頂点を内包するバウンディングボックス。当り判定用
	Vector3f centering; /// 当り判定用

	SdefSkin[] parts; /// このボーンに所属するモデル。スキン毎に分類されている。

	/// vertex[ face[0] ] が原点、vertex[ face[1] ] がボーン先端。
	this( int id, Vector3f[] boneV, uint[] boneF, Bone parent )
	{
		this.id = id;
		this.parent = parent;

		auto ts = Tranf( boneV[ boneF[0] ], boneV[ boneF[1] ], boneV[ boneF[2] ] );
		localize = ts;

		if( null !is parent )
		{
			ts = Tranf( parent.localize * boneV[ boneF[0] ]
			          , parent.localize * boneV[ boneF[1] ]
			          , parent.localize * boneV[ boneF[2] ] );
		}

		globalize = -ts.translation;
	}

	/// transform を更新する。
	void update( float f, ref const(Tranf) parent_globalize )
	{
		currentGlobalize = parent_globalize;
		currentGlobalize += globalize;
		if( null !is motion ) currentGlobalize *= motion[f];
		transform = (currentGlobalize * localize).toMatrix; // 完成

		// 当り判定用
		bbox.localize.translation = centering;
		bbox.localize.rotation = Quaternionf();
		bbox.localize *= -currentGlobalize;

		// 子に適用
		foreach( child ; children ) child.update( f, currentGlobalize );
		if( null !is little_brother ) little_brother.update( f, parent_globalize );
	}

}

/*SSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSS*\
|*|                                SdefVertex                                |*|
\*SSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSS*/
/**
 * 頂点情報
 * ToDo:
 *   今後、メンバを増やしていく予定。
 */
struct SdefVertex
{
	Vector3f pos; /// 位置
	UVf uv; /// テクスチャ座標
	alias pos this;

	int[4] mat = [ -1, -1, -1, -1 ]; /// 影響を受ける変換行列
	float[4] influence = [ 0f, 0, 0, 0 ]; /// それぞれの行列の影響度。∫= 1
}

/*SSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSS*\
|*|                                 SdefSkin                                 |*|
\*SSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSS*/
/**
 * スキン毎に分類されたインデックスを格納する。
 */
struct SdefSkin
{
	int vertex_id; /// BoneSystem.skins[ vertex_id ] の頂点座標を使う。
	SdefIndex[] faces; /// マテリアル毎に分類されている。
}

/*SSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSS*\
|*|                                SdefIndex                                 |*|
\*SSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSS*/
/**
 * Bugs:
 *   モデルのスキンはトライアングルのみ。ラインは無視される。
 */
struct SdefIndex
{
	MikotoMaterial material;
	uint[] faces; /// GL_TRIANGLES;
	alias faces this;

	this( MikotoMaterial m ){ this.material = m; }
}

/*FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF*\
|*|                           mikotoModelToBoneSet                           |*|
\*FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF*/
/**
 * MikotoModel から必要な情報を得る。
 * Bugs:
 *   複数のルートボーンがあった場合はどうするのか？$(BR)
 *   → 現状では最初に見つかったルートボーンしか返しません。
 */
BoneSet mikotoModelToBoneSet( MikotoModel mm, jstring bone_name = "".j )
{
	//           ┌ "sdef:" を除いたスキン名
	SdefSkin[jstring] sdefs;
	//          ┌ ObjectChunk 毎に分れている。
	SdefVertex[][] skins;
	
	//          ┌─── マテリアルのインデックス値
	//          ↓    ┌ 対象の sdef 毎に分れている。
	AnchorFace[int][jstring] anchors;

	//       ┌ マテリアルのインデックス値
	BoneInfo[int] binfo;

	//
	BoneSet bs;

	foreach( skin ; mm.skins )
	{
		if     ( skin.name.startsWith( "sdef:".j ) )
		{
			sdefs[ skin.name[ 5 .. $ ] ] = mikotoSkinToSdefSkin( skin, mm.materials, skins );
		}
		else if( skin.name.startsWith( "bone:".j ) )
		{
			if( null !is bs.bsys || ( 0 < bone_name.length && skin.name[ 5 .. $ ] != bone_name ) ) continue;

			auto bi = mikotoSkinToFlatBoneInfo( skin, mm.materials );
			fillBoneInfosFamily( bi );
			
			foreach( i, one ; bi )
			{
				if( null is bs.bsys && null is one.bone && null is one.parent && null is one.big_brother )
				{
					Bone[] bones;
					one.makeBone( skin.vertex, bones, bs.bone_id );
					bs.bsys = new BoneSystem( bones );
					for( BoneInfo bi = one ; null !is bi ; bi = bi.little_brother )
						bs.roots ~= bi.material_name;
				}
			}
			foreach( i, one ; bi ) if( null !is one.bone ) binfo[i] = one;
		}
		else if( skin.name.startsWith( "anchor".j ) )
		{
			auto name = skin.name[ 6 .. $ ];
			name.findSkip("|".j);
			for( size_t i ; i < skin.faces.length ; i++ )
			{
				anchors[name][ skin.faces[i].material_id ]
					= AnchorFace( skin.faces[i].material_id, skin.vertex, skin.faces[i].index );
			}
		}
	}

	assert( null !is bs.bsys );

	foreach( key, skin ; sdefs )
	{
		auto anc = anchors.get( key, null );
		if( null is anc ) continue;
		setInfluencesSlot( bs.bsys.bones, binfo, anc, skins[ skin.vertex_id ], skin );
	}
	bs.bsys.skins = skins;

	return bs;
}

//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\
////                                                                        \\\\
////                                private                                 \\\\
////                                                                        \\\\
//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\
/*############################################################################*\
|*#                                                                          #*|
|*#                              analyzing sdef                              #*|
|*#                                                                          #*|
\*############################################################################*/
/*FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF*\
|*|                           mikotoSkinToSdefSkin                           |*|
\*FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF*/
/*
 * Bugs:
 *   ポリラインは無視しています。
 */
private SdefSkin mikotoSkinToSdefSkin( MikotoSkin skin, MikotoMaterial[] materials, ref SdefVertex[][] skins )
{
	SdefSkin ss;
	ss.vertex_id = skins.length;
	auto vert = new SdefVertex[ skin.vertex.length ];
	foreach( i, ref one ; vert ) one.pos = skin.vertex[i];

	ss.faces = new SdefIndex[ skin.faces.length ];
	foreach( i, ref one ; ss.faces )
	{
		one.material = materials[ skin.faces[i].material_id ];
		one.faces = skin.faces[i].index;
		if( 0 < skin.faces[i].uv.length )
		{
			foreach( j, idx ; skin.faces[i].index ) vert[ idx ].uv = skin.faces[i].uv[j];
		}
	}

	skins ~= vert;
	return ss;
}

/*############################################################################*\
|*#                                                                          #*|
|*#                              analyzing bone                              #*|
|*#                                                                          #*|
\*############################################################################*/
/*CCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCC*\
|*|                                 BoneInfo                                 |*|
\*CCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCC*/
/*
 * ボーンの状態を格納する一時オブジェクト$(BR)
 * Bugs:
 *   ボーンの家族関係の解決にインデックス値を使っているため、別レイヤに渡って家族関係を持つことはできない。
 */
private class BoneInfo
{
	union
	{
		uint[3] v;
		struct
		{
			uint zero; // 最長辺の対角
			uint tip;  // 最長辺と第二長辺の交点
			uint handle; // 最長辺と最短辺の交点
		}
	}
	uint[] floating_tip; // 浮動ボーンの先端

	BoneInfo parent; // 親ボーン。
	BoneInfo[] children; // 子ボーン。
	BoneInfo big_brother; // 兄弟ボーン。軸の原点を共有する。
	BoneInfo little_brother; // ditto

	jstring material_name; // マテリアル名

	Bone bone; // 生成された Bone
	alias bone this;

	///
	this( jstring mname, uint[] v )
	{
		this.material_name = mname;
		this.v[] = v;
	}

	/*
	 * BoneInfo から Bone を生成し、返す。$(BR)
	 */
	Bone makeBone( Vector3f[] boneV, ref Bone[] boneStore, ref int[jstring] nameStore )
	{
		if( null !is bone ) return bone;
		bone = new Bone( boneStore.length, boneV, v[], null !is parent ? parent.bone : null );
		nameStore[material_name] = bone.id;
		boneStore ~= bone;
		foreach( child ; children )
		{
			bone.children ~= child.makeBone( boneV, boneStore, nameStore );
		}
		if( null !is little_brother )
		{
			bone.little_brother = little_brother.makeBone( boneV, boneStore, nameStore );
			bone.little_brother.big_brother = bone;
		}
		return bone;
	}
}

/*FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF*\
|*|                         mikotoSkinToFlatBoneTree                         |*|
\*FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF*/
/*
 * オブジェクトチャンクから BoneTree にする。$(BR)
 * BoneTree の親子関係はまだ判明していない状態。
 */
private BoneInfo[int] mikotoSkinToFlatBoneInfo( MikotoSkin skin, MikotoMaterial[] materials )
{
	BoneInfo[int] binfo;

	/*
	 * face[0] が原点(最長辺の対角)に、
	 * face[1] が Z軸(最長辺と第二長辺の交点)になるように整列させる。
	 */
	bool sortTriangleBone( uint[] face, Vector3f[] vertex )
	{
		if( 3 != face.length ) return false;
		auto l01 = vertex[ face[0] ].distanceSq( vertex[ face[1] ] );
		auto l12 = vertex[ face[1] ].distanceSq( vertex[ face[2] ] );
		auto l20 = vertex[ face[2] ].distanceSq( vertex[ face[0] ] );

		for( ; ; )
		{
			if     ( l20 <= l01 && l01 <= l12 ) break;
			else if( l01 < l20 && l20 <= l12 ){ face[1].swap( face[2] ); l01.swap( l20 ); }
			else if( l01 < l12 && l12 <= l20 ){ face[0].swap( face[1] ); l12.swap( l20 ); }
			else if( l12 < l01 && l01 <= l20 ){ face[0].swap( face[1] ); l12.swap( l20 ); }
			else if( l20 < l12 && l12 <= l01 ){ face[0].swap( face[2] ); l01.swap( l12 ); }
			else if( l12 < l20 && l20 <= l01 ){ face[0].swap( face[2] ); l01.swap( l12 ); }
		}
		return true;
	}

	foreach( bone ; skin.faces )
	{
		assert( 3 <= bone.index.length );
		sortTriangleBone( bone.index, skin.vertex );
		binfo[ bone.material_id ] = new BoneInfo( materials[bone.material_id].name, bone.index );
	}

	// 浮動ボーンを準備する。
	// 浮動ボーンは材質に関係なく親子関係が決定されるようである。
	uint[] lines;
	foreach( line ; skin.lines ) lines ~= line.index;
	for( size_t i = 0, counter = 0 ; ; )
	{
		bool flag = false;
		foreach( ref bi ; binfo )
		{
			if     ( lines[i] == bi.tip ) { bi.floating_tip ~= lines[i+1]; flag = true; }
			else if( lines[i+1] == bi.tip ) { bi.floating_tip ~= lines[i]; flag = true; }
			else
			{
				for( size_t j = 0 ; j < bi.floating_tip.length && !flag ; j++ )
				{
					if     ( lines[i] == bi.floating_tip[j] ) { bi.floating_tip ~= lines[i+1]; flag = true; }
					else if( lines[i+1] == bi.floating_tip[j] ) { bi.floating_tip ~= lines[i]; flag = true; }
				}
			}
			if( flag ) break;
		}

		if( flag ){ lines = lines[ 0 .. i ] ~ lines[ i+2 .. $ ]; counter++; }
		else i += 2;

		if     ( i+1 < lines.length ) { }
		else if( lines.length < 2 ) break;
		else if( 0 == counter ) break;
		else { i = 0; counter = 0; }
	}

	return binfo;
}

/*FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF*\
|*|                           fillBoneInfosFamily                            |*|
\*FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF*/
/*
 * BoneTree の家族関係を解決する。
 *
 * Bugs:
 *   同じモデルファイルに複数のルートボーンがあった場合は、最初のルートボーンのみを返す。
 *   ※ ルートボーンとは、ボーンの家族関係の最上位であると定義している。$(BR)
 *      ボーンがその原点(最長辺の対角)を他のボーンの原点と共有している場合、家族関係は兄弟とされ、
 *      その序列はおそらくパーサの実装に拠る。$(BR)
 *      現状、ファイル上で最初に出現した方が兄になっていると思われる。$(BR)
 *
 *   ボーンが輪のように閉じ、序列をつけられない場合、null を返す。
 */
private void fillBoneInfosFamily( BoneInfo[int] binfo )
{
	void fillChildren( BoneInfo bt )
	{
		if( 0 < bt.children.length ) return;
		foreach( one ; binfo )
		{
			if     ( bt is one ){ }
			else if( bt.tip == one.zero ){ bt.children ~= one; one.parent = bt; }
			else if( bt.zero == one.zero )
			{
				if( null is bt.little_brother && null is one.big_brother && one.little_brother !is bt )
				{
					bt.little_brother = one;
					one.big_brother = bt;
				}
			}
			else
			{
				foreach( ft ; bt.floating_tip )
				{
					if( ft == one.zero ){ bt.children ~= one; one.parent = bt; break; }
				}
			}
		}
	}
	foreach( one ; binfo ) fillChildren( one );
}

/*############################################################################*\
|*#                                                                          #*|
|*#                             analyzing anchor                             #*|
|*#                                                                          #*|
\*############################################################################*/
/*CCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCC*\
|*|                                AnchorFace                                |*|
\*CCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCC*/
/*
 * アンカーの情報が入っている。$(BR)
 * ひとつのアンカーは以下の条件を満すと仮定しているが、後になるほどあやしい。$(BR)
 * <ol>
 *   <li> 単一の Material からなる。</li>
 *   <li> 単一の閉じたメッシュである。</li>
 *   <li> ひとつのObjectチャンク(Metasequoia上ではひとつのレイヤ(?))の情報で一つのメッシュとして完結している。</li>
 *   <li> 各トライアングルの表裏が正しい。(内側から見たら全部裏向き)</li>
 * </ol>
 * ※ トライアングルの表裏は MikotoFace によって Metasequoia式(clockwise) -&gt; OpenGL式(counter-clockwise)
 * に事前に変換されているとする。
 */
private struct AnchorFace
{
	int name; /// マテリアルインデックス値
	Vector3f[] vertex; /// アンカーを構成する頂点
	uint[] faces;

	///
	this( int name, Vector3f[] vertex, uint[] f )
	{
		this.name = name;
		this.vertex = vertex;
		this.faces = f;
	}

	/*
	 * このアンカーに含まれている頂点に対して影響度をセットする。$(BR)
	 * 影響度は、ボーンの Z軸に平行な向きでの、アンカーメッシュ端までの深さできまる。$(BR)
	 * ( ↑ この実装が最も本家に近いように思われる。OpenRDB のソースを読まねば。)$(BR)
	 * ついでに、ボーンの OBB も作っておく。$(BR)
	 */
	void ready( SdefVertex[] vertex, BoneInfo bi, InfluenceSet[][] influence )
	{
		auto arr = Arrowf( [ 0.0f, 0, 0 ], Vector3f( 0, 0, 1 ) * bi.bone.localize );
		float max_x, max_y, max_z, min_x, min_y, min_z;
		max_x = max_y = max_z = -float.max;
		min_x = min_y = min_z = float.max;
		Vector3f vec;

		foreach( i, v ; vertex )
		{
			arr.p = v.pos;
			auto inf = arr.depthIn( this.vertex, faces );
			if( 0 < inf )
			{
				influence[ i ] ~= InfluenceSet( bi, inf );
				vec = bi.bone.localize * v.pos;
				max_x = max( vec.x, max_x ); max_y = max( vec.y, max_y ); max_z = max( vec.z, max_z );
				min_x = min( vec.x, min_x ); min_y = min( vec.y, min_y ); min_z = min( vec.z, min_z );
			}
		}

		bi.centering = Vector3f( ( max_x + min_x ) * -0.5, ( max_y + min_y ) * -0.5, ( max_z + min_z ) * -0.5 );
		bi.bbox.width2 = Vector3f( ( max_x - min_x ) * 0.5, ( max_y - min_y ) * 0.5, ( max_z - min_z ) * 0.5 );
	}
}

/*############################################################################*\
|*#                                                                          #*|
|*#                                ready bone                                #*|
|*#                                                                          #*|
\*############################################################################*/
/*FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF*\
|*|                            setInfluencesSlot                             |*|
\*FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF*/
/*
 * それぞれの頂点の影響度の情報を vertex にセットする。$(BR)
 * 同時に複数のアンカーに含まれる頂点は影響の大きい方から4つのアンカーの影響を受ける。$(BR)
 * OpenRDB では「最大4つのアンカーの影響を受けることができる」らしいのだが、4つもいるかなあ？$(BR)
 * スカートとか布みたいなメッシュを考えると余裕でいりそうだが。$(BR)
 */
private void setInfluencesSlot( Bone[] bones, BoneInfo[int] binfo, AnchorFace[int] anchors, SdefVertex[] vertex
                              , SdefSkin skin )
{
	// 影響度を設定
	InfluenceSet[][] variable_influences = new InfluenceSet[][vertex.length];
	foreach( key, bi ; binfo )
	{
		if( key !in anchors ) continue;
		anchors[key].ready( vertex, bi, variable_influences );
	}
	catchLonelyVertex( vertex, binfo, variable_influences );
	auto ninf = normalizeInfluences( variable_influences );

	foreach( i, ref one ; vertex )
	{
		if( null is ninf[i][0].bi ) continue;
		one.mat[0] = ninf[i][0].id;
		one.influence[0] = ninf[i][0].influence;
		if( null is ninf[i][1].bi ) continue;
		one.mat[1] = ninf[i][1].id;
		one.influence[1] = ninf[i][1].influence;
		if( null is ninf[i][2].bi ) continue;
		one.mat[2] = ninf[i][2].id;
		one.influence[2] = ninf[i][2].influence;
		if( null is ninf[i][3].bi ) continue;
		one.mat[3] = ninf[i][3].id;
		one.influence[3] = ninf[i][3].influence;
	}

	// 各ボーンに分配
	// インデックス値 == 0 の時 → ルートボーンであり、値が大きくなる程子孫になる。
	// 最もインデックス値が大きいボーンがそのトライアングルを所有するものとする。
	int littleBone( ref in SdefVertex sv )
	{
		int i = -1;
		if( i < sv.mat[0] ) i = sv.mat[0];
		if( i < sv.mat[1] ) i = sv.mat[1];
		if( i < sv.mat[2] ) i = sv.mat[2];
		if( i < sv.mat[3] ) i = sv.mat[3];
		return i;
	}

	int mostLittleBone( ref in SdefVertex sv1, ref in SdefVertex sv2, ref in SdefVertex i3 )
	{
		auto b = littleBone( sv1 );
		auto tb = littleBone( sv2 );
		if( b < tb ) b = tb;
		tb = littleBone( i3 );
		if( b < tb ) b = tb;
		return b;
	}

	foreach( face ; skin.faces )
	{
		for( size_t i = 0 ; i+3 <= face.length ; i+=3 )
		{
			auto bidx = mostLittleBone( vertex[face[i]], vertex[face[i+1]], vertex[face[i+2]] );
			if( bidx < 0 || bones.length <= bidx ) continue;
			auto b = bones[ bidx ];
			if( 0 == b.parts.length || b.parts[$-1].vertex_id != skin.vertex_id )
				b.parts ~= SdefSkin( skin.vertex_id, null );
			if( 0 == b.parts[$-1].faces.length || b.parts[$-1].faces[$-1].material !is face.material )
				b.parts[$-1].faces ~= SdefIndex( face.material );
			b.parts[$-1].faces[$-1] ~= face[ i .. i+3 ];
		}
	}

}

/*SSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSS*\
|*|                               InfluenceSet                               |*|
\*SSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSS*/
// 影響度を格納する一時オブジェクト
private struct InfluenceSet
{
	BoneInfo bi;
	alias bi this;
	float influence;
}

/*FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF*\
|*|                            catchLonelyVertex                             |*|
\*FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF*/
/*
 * AnchorFace.ready を実行して、influence の値がひと通り埋まってから実行する。$(BR)
 * OpenRDB には、「全ての頂点は何れかのアンカーに含まれている必要がある。」とあるが、Mikoto では
 * 「アンカーに含まれていない頂点は、最寄りのボーンの影響を受ける」らしい。$(BR)
 * ボーンの原点までの距離で比較し、最寄りのボーンを探している。
 */
private void catchLonelyVertex( SdefVertex[] vertex, BoneInfo[int] binfo, InfluenceSet[][] influence )
{
	BoneInfo getNearestBone( ref const(Vector3f) pos )
	{
		BoneInfo result = null;
		float dist = float.max;
		foreach( bi ; binfo )
		{
			auto d = ( bi.bone.localize * pos ).lengthSq;
			if( d < dist ){ dist = d; result = bi; }
		}
		return result;
	}

	foreach( i, ref inf ; influence )
	{
		if( 0 == inf.length )
		{
			auto nb = getNearestBone( vertex[i].pos );
			if( null !is nb ) inf ~= InfluenceSet( nb, 1.0 );
		}
	}
}

/*FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF*\
|*|                           normalizeInfluences                            |*|
\*FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF*/
/*
 * 影響度の大きい方から4つを選択し、影響度を正規化(その頂点について合計すると 1 になるように)する。
 */
private InfluenceSet[4][] normalizeInfluences( InfluenceSet[][] inf )
{
	InfluenceSet[4][] result = new InfluenceSet[4][ inf.length ];
	float total;

	foreach( i, one ; inf )
	{
		sort!"a.influence >= b.influence"( one );
		total = 0.0;

		for( size_t j = 0 ; j < 4 && j < one.length ; j++ )
		{
			result[i][j] = one[j];
			total += one[j].influence;
		}
		if( 0.0 == total || float.nan is total ) continue;
		else total = 1 / total;

		for( size_t j = 0 ; j < 4 ; j++ ) result[i][j].influence *= total;
	}
	return result;
}

////////////////////XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX\\\\\\\\\\\\\\\\\\\\
debug(bone_system):
import sworks.mqo.mqo;
import sworks.mqo.parser;
import sworks.mqo.mikoto_model;

void main()
{
	auto mqo = load!MQObject( "dsan\\Dさん.mqo" );
	auto mm = mqoToMikotoModel( mqo );
	auto bs = mikotoModelToBoneSet( mm );

	auto bid = bs.bone_id[ "LegB[L]".j ];
//	writeln( bs.bsys.bones[i].parts.dump_members( 3, 20 ) );
//*/
	foreach( i, b ; bs.bsys.bones )
	{
		writeln( i, " : ", b.parts.length );
	}
//*/
}
