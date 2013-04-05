/** MikotoModel を動かす為にボーンを準備する。
 * Version:      0.0014(dmd2.062)
 * Date:         2013-Apr-06 01:08:29
 * Authors:      KUMA
 * License:      CC0
 */
module sworks.mqo.bone_system;

import std.algorithm, std.exception;
import sworks.compo.util.matrix;
import sworks.mqo.misc;
import sworks.mqo.mikoto_model;
debug import std.stdio, sworks.compo.util.dump_members;

/*SSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSS*\
|*|                          VertexLayoutDescriptor                          |*|
\*SSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSS*/
/**
 * 頂点座標を格納する構造体の定義に使う。
 * Example:
 * -----------------------------------------------------------------------------
 * $(D_KEYWORD struct) Vertex
 * {
 *     @VLD_POSITION $(D_KEYWORD float)[3] pos;    // 頂点座標
 *     @VLD_NORMAL   $(D_KEYWORD float)[3] normal; // 法線ベクトル
 * }
 * -----------------------------------------------------------------------------
 */
struct VertexLayoutDescriptor { string type; }
/// ditto
enum VLD_POSITION = VertexLayoutDescriptor("POSITION");
/// ditto
enum VLD_NORMAL = VertexLayoutDescriptor("NORMAL");
/// ditto
enum VLD_TEXTURE = VertexLayoutDescriptor( "TEXTURE[0]" );
/// ditto
enum VLD_MATRIX = VertexLayoutDescriptor( "MATRIX" );        // ┐
/// ditto
enum VLD_INFLUENCE = VertexLayoutDescriptor( "INFLUENCE" );  // ┴ この2つはセットで使う。

/*SSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSS*\
|*|                            AttributeConnector                            |*|
\*SSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSS*/
/**
 * 構造体 T のうち、ATTR の UDA を持つ(最初の)メンバへのアクセスに。
 * Example:
 * -----------------------------------------------------------------------------
 * Vertex v; // 上記の構造体。
 * $(D_KEYWORD alias) pos_connector = AttributeConnector!( Vertex, VLD_POSITION );
 * pos_connector(v) = [ 3.0, 4.0, 5.0 ]; // v.pos へアクセスできる。
 * -----------------------------------------------------------------------------
 */
struct AttributeConnector( T, alias ATTR )
{
	enum member = _getName();
	enum active = 0 < member.length;

	static if( 0 < member.length ) alias TYPE = typeof( __traits( getMember, T, member ) );
	else { alias TYPE = int; }

	private static string _getName()
	{
		foreach( m ; __traits( derivedMembers, T ) )
		{
			foreach( attr ; __traits( getAttributes, __traits( getMember, T, m ) ) )
			{
				if( ATTR == attr ) return m;
			}
		}
		return "";
	}

	/// UDA ATTR を持つメンバを得る。そんなメンバがない場合は $(D_KEYWORD assert)(0);
	static ref inout(TYPE) opCall( ref inout(T) t )
	{
		static if( active ) return __traits( getMember, t, member );
		else assert(0);
	}
}

/*SSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSS*\
|*|                                 BoneSet                                  |*|
\*SSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSS*/
/**
 * ボーンの名前(マテリアル名)と BoneSystem.bones でのインデックス値を紐付けするための一時オブジェクト。$(BR)
 * MikotoMotion のモーションを適用する際に参照される。$(BR)
 */
struct BoneSet(VERTEX)
{
	BoneSystem bsys; /// 対象となる BoneSystem
	VERTEX[][] skins; /// bones で使われる全スキン。由来する ObjectChunk 毎に分類してある。
	int[jstring] bone_id; /// マテリアル名 -&gt; インデックス
	/*
	 * <del>bsys のルートボーンとその兄弟ボーンの名前を格納している。$(BR)
	 * モーション適用時、ルートボーンのみは平行移動する</del>( &lt;- ウソ。どのボーンも平行移動します。)<del>が、
	 * mkm ファイル内で兄弟ボーンの内どれが最上位とされているのか不明の為、全て列挙しておく。</del>$(BR)
	jstring[] roots;
	 */
}

/*CCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCC*\
|*|                                BoneSystem                                |*|
\*CCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCC*/
/**
 * ルートボーンとその子ボーンを管理する。$(BR)
 *
 * Bugs:
 *   頂点インデックス/マテリアル情報は、BoneSystem が管理している。(なんとなく違和感があるので変えるかも。)$(BR)
 *   Bone 下にスキンのインデックス、マテリアル情報も持たせている。
 */
class BoneSystem
{
	Bone[] bones; /// このシステムに含まれる全てのボーン。roots も含まれる。
	Bone[] roots; /// bones のうち、親ボーンを持たないボーン

	TranslateMotion world_translate; /// ローカルワールド座標の平行移動運動
	RotateMotion world_rotate; /// ローカルワールド座標の回転移動運動

	/**
	 * Params:
	 *   bones = bones[0] がルートとする。
	 */
	this( Bone[] roots, Bone[] bones )
	{
		this.roots = roots;
		this.bones = bones;
	}


	/// システムの変換行列を更新する。
	void update( float f )
	{
		Tranf worldGlobalize;
		if( null !is world_translate ) worldGlobalize.translation = world_translate[f];
		if( null !is world_rotate ) worldGlobalize.rotation = world_rotate[f];
		foreach( root ; roots ) root.update( f, worldGlobalize );
	}

}

/*CCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCC*\
|*|                                   Bone                                   |*|
\*CCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCC*/
/**
 * Mikoto のボーン。最長辺の対角が原点。$(BR)
 * 第二長辺が、Z軸正の向き。$(BR)
 * 最短辺と第二長辺の外積が X軸正の向きになっていると思われる。たぶん。$(BR)
 *
 * Bugs:
 *   現在スキンのインデックス値も保持しているが、なんとなく違和感があるので変えるかも。$(BR)
 */
class Bone
{
	int id; /// <del>0 がルートとなる、</del>ボーンの ID。BoneSystem.bones のインデックス値。
	Bone parent; /// 親ボーン。
	Bone[] children; /// 子ボーン。
	Bone[] neighbours; /// Anchor が干渉しあう Bone。自身は含まれない。
	Bone[] brothers;   /// ボーンの原点を同じくする弟ボーン。自身は含まれない。Materialチャンクで先に出てくるBoneが兄(たぶん)。
	                   /// 兄弟ボーンは平行移動のみ共有する。

	Tranf localize; /// 一般ワールド座標 -&gt; origin を原点とするローカル座標への変換
	Vector3f globalize; /// ローカル座標 -&gt; 一つ上のボーンのローカル座標へ。
	Tranf currentGlobalize; /// アニメーション用にアップデートされる。
	/**
	 * 変換行列の最終的な変形結果が格納される。$(BR)
	 * シェーダなどから、これを参照する。
	 */
	Matrix4f transform;

	/**
	 * 現在適用中のモーション。<del>ルートボーン以外は平行移動しない。</del>&lt;-これはウソ。ボーンの原点を右クリ、ロック解除で移動できました。$(BR)
	 * ボーンの先端(ローカル座標のZ軸正の向き)がワールド座標の Z軸正の向きと一致する位置からの回転を示している。
	 */
	TranslateMotion translation;
	/// ditto
	RotateMotion rotation;

	OBBox bbox; /// 頂点を内包するバウンディングボックス。当り判定用
	Vector3f centering; /// 当り判定用

	SdefPart[] parts; /// このボーンに所属するモデル。スキン毎に分類されている。

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
			globalize = -ts.translation;
		}
	}

	/// transform を更新する。
	void update( float f, ref const(Tranf) parent_globalize )
	{
		currentGlobalize = parent_globalize;
		currentGlobalize += globalize;
		if( null !is translation ) currentGlobalize += translation[f];
		foreach( bro ; brothers ) bro.update( f, currentGlobalize ); // 弟ボーンには自身の回転運動は影響しない。
		if( null !is rotation ) currentGlobalize *= rotation[f];
		transform = (currentGlobalize * localize).toMatrix; // 完成

		// 当り判定用
		bbox.localize.translation = centering;
		bbox.localize.rotation = Quaternionf();
		bbox.localize *= -currentGlobalize;

		// 子に適用
		foreach( child ; children ) child.update( f, currentGlobalize );
	}

	/// 法線ベクトルを準備する。
	void addNormalVector(VERTEX)( VERTEX[][] skins )
	{
		foreach( part ; parts )
		{
			part.addNormalVector( skins[ part.vertex_id ] );
		}
	}
}

/*SSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSS*\
|*|                                 SdefPart                                 |*|
\*SSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSS*/
/**
 * スキン毎に分類されたインデックスを格納する。
 */
struct SdefPart
{
	int vertex_id; /// BoneSet.skins[ vertex_id ] の頂点座標を使う。
	               /// (備忘 なんで配列そのものでなくインデックス値で保持してるかというとヴァーテックスオブジェクトとか使い安いように。)
	SdefFace[] faces; /// マテリアル毎に分類されている。

	/// 法線ベクトルを準備する。
	void addNormalVector(VERTEX)( VERTEX[] v )
	{
		alias pos_attr = AttributeConnector!( VERTEX, VLD_POSITION );
		alias normal_attr = AttributeConnector!( VERTEX, VLD_NORMAL );
		static assert( pos_attr.active && normal_attr.active );
		pos_attr.TYPE v0, v1, v2, n;
		foreach( f ; faces )
		{
			for( size_t i = 0 ; i < f.index.length ; i+=3 )
			{
				v0 = pos_attr( v[ f.index[i] ] );
				v1 = pos_attr( v[ f.index[i+1] ] );
				v2 = pos_attr( v[ f.index[i+2] ] );
				n = (v1-v0).cross( v2-v0 );

				normal_attr( v[ f.index[i] ] ) += n;
				normal_attr( v[ f.index[i+1] ] ) += n;
				normal_attr( v[ f.index[i+2] ] ) += n;
			}
		}
	}
}

/*SSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSS*\
|*|                                SdefFace                                  |*|
\*SSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSS*/
/**
 * Bugs:
 *   モデルのスキンはトライアングルのみ。ラインは無視される。
 */
struct SdefFace
{
	MikotoMaterial material;
	uint[] index; /// GL_TRIANGLES;
	alias index this;
}

/*FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF*\
|*|                           mikotoModelToBoneSet                           |*|
\*FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF*/
/**
 * MikotoModel から必要な情報を得る。
 * Bugs:
 *   複数のルートボーンがあった場合はどうするのか？$(BR)
 *   <del>→ 現状では最初に見つかったルートボーンしか返しません。</del>(ver 0.0014以降)$(BR)
 *   複数のルートボーンを保持した BoneSystem を返すようになりました。
 */
BoneSet!VERTEX mikotoModelToBoneSet(VERTEX)( MikotoModel mm, jstring bone_name = "".j )
{
	//           ┌ "sdef:" を除いたスキン名
	SdefPart[jstring] sdefs; // アンカーから anchorHoge|SdefName のように対象 SdefPart を指定できる。これを解決する為に使う。
	//      ┌ ObjectChunk 毎に分れている。
	VERTEX[][] skins; // BoneSet.skins に格納される。
	
	//          ┌─── ─ マテリアルのインデックス値。binfoのインデックスに一致する。
	//          │    ┌ 対象の sdef 毎に分れている。sdefsのインデックスに一致する。
	AnchorFace[int][jstring] anchors;

	//       ┌ マテリアルのインデックス値。AnchorFaceのインデックスに一致する。
	BoneInfo[int] binfo;

	//
	BoneSet!VERTEX bs; // 戻り値

	foreach( skin ; mm.skins )
	{
		if( skin.name.startsWith( "sdef:".j ) )
		{
			sdefs[ skin.name[ 5 .. $ ] ] = mikotoSkinToSdefPart( skin, mm.materials, skins );
		}
		else if( skin.name.startsWith( "bone:".j ) )
		{
			if( null !is bs.bsys || ( 0 < bone_name.length && skin.name[ 5 .. $ ] != bone_name ) ) continue;

			auto bi = mikotoSkinToFlatBoneInfo( skin, mm.materials );
			fillBoneInfosFamily( bi );
			BoneInfo[] roots;
			auto sbi = sortBoneInfo( bi, roots );
			
			auto bones = new Bone[ sbi.length ];
			foreach( i, one ; sbi )
			{
				bones[i] = one.makeBone( skin.vertex );
				bs.bone_id[ one.material_name ] = i;
			}

			bs.bsys = new BoneSystem( bones[ 0 .. roots.length ], bones );

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

	enforce( null !is bs.bsys );

	// 頂点インデックスをボーンに振り分け
	foreach( key, skin ; sdefs )
	{
		auto anc = anchors.get( key, null );
		if( null is anc ) continue;
		setInfluencesSlot( bs.bsys.bones, binfo, anc, skins[ skin.vertex_id ], skin );
	}
	bs.skins = skins;

	// 法線ベクトルを準備
	alias normal_attr = AttributeConnector!( VERTEX, VLD_NORMAL );
	static if( normal_attr.active )
	{
		foreach( bone ; bs.bsys.bones ) bone.addNormalVector( skins );
		foreach( skin ; skins ){ foreach( ref v ; skin ){ normal_attr( v ).normalize; } }
	}

	return bs;
}

//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\
//||                                                                        ||\\
//||                                private                                 ||\\
//||                                                                        ||\\
//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\
/*############################################################################*\
|*#                                                                          #*|
|*#                              analyzing sdef                              #*|
|*#                                                                          #*|
\*############################################################################*/
/*FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF*\
|*|                           mikotoSkinToSdefPart                           |*|
\*FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF*/
/*
 * Bugs:
 *   ポリラインは無視しています。
 */
private SdefPart mikotoSkinToSdefPart(VERTEX)( MikotoSkin skin, MikotoMaterial[] materials, ref VERTEX[][] skins )
{
	SdefPart ss;
	ss.vertex_id = skins.length;
	auto vert = new VERTEX[ skin.vertex.length ];
	alias aba = AttributeConnector!( VERTEX, VLD_POSITION );
	static if( aba.active ) foreach( i, ref one ; vert ) aba( one ) = skin.vertex[i];

	ss.faces = new SdefFace[ skin.faces.length ];
	alias uv_attr = AttributeConnector!( VERTEX, VLD_TEXTURE );
	foreach( i, ref one ; ss.faces )
	{
		one.material = materials[ skin.faces[i].material_id ];
		one.index = skin.faces[i].index;
		static if( uv_attr.active )
		{
			if( 0 < skin.faces[i].uv.length )
			{
				foreach( j, idx ; skin.faces[i].index ) uv_attr( vert[ idx ] ) = skin.faces[i].uv[j];
			}
		}
	}

	skins ~= vert;
	return ss;
}

/*############################################################################*\
|*#                                                                          #*|
|*#                               analyze bone                               #*|
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
	BoneInfo big_brother; // 兄( ファイル上の Material チャンク内で先に出てくるマテリアルを持つボーンが兄)
	BoneInfo[] brothers;  // 弟たち。

	jstring material_name; // マテリアル名

	Bone bone; // 生成された Bone
	alias bone this;

	int id; // 親子関係で整列後の0開始の順序

	///
	this( jstring mname, uint[] v )
	{
		this.material_name = mname;
		this.v[] = v;
	}

	/*
	 * BoneInfo から Bone を生成し、返す。$(BR)
	 */
	Bone makeBone( Vector3f[] boneV )
	{
		if( null !is bone ) return bone;
		bone = new Bone( id, boneV, v[], null !is parent ? parent.bone : null );
		foreach( child ; children ) bone.children ~= child.makeBone( boneV );
		foreach( bro ; brothers ) bone.brothers ~= bro.makeBone( boneV );
		return bone;
	}
}

/*FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF*\
|*|                         mikotoSkinToFlatBoneInfo                         |*|
\*FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF*/
/*
 * オブジェクトチャンクから BoneTree にする。$(BR)
 * BoneInfo の親子関係はまだ判明していない状態。
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
	size_t count = 0; foreach( line ; skin.lines ) count += line.index.length;
	uint[] lines = new uint[count];
	count = 0; foreach( line ; skin.lines ) { lines[ count .. count + line.index.length ] = line.index; count += line.index.length; }
	outloop: for(  ; 1 < lines.length ; lines = lines[ 2 .. $ ] )
	{
		foreach( bi ; binfo )
		{
			if( lines[0] == bi.tip ) { bi.floating_tip ~= lines[1]; break; }
			if( lines[1] == bi.tip ) { bi.floating_tip ~= lines[0]; break; }
			for( size_t j = 0 ; j < bi.floating_tip.length ; j++ )
			{
				if( lines[0] == bi.floating_tip[j] ) { bi.floating_tip ~= lines[1]; continue outloop; }
				if( lines[1] == bi.floating_tip[j] ) { bi.floating_tip ~= lines[0]; continue outloop; }
			}
		}
	}

	return binfo;
}

/*FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF*\
|*|                           fillBoneInfosFamily                            |*|
\*FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF*/
/*
 * BoneInfo の家族関係を解決する。
 *
 * Bugs:
 *   同じモデルファイルに複数のルートボーンがあった場合は、<del>最初のルートボーンのみを返す。</del>全部返す
 *   ※ ルートボーンとは、ボーンの家族関係の最上位であると定義している。$(BR)
 *      ボーンがその原点(最長辺の対角)を他のボーンの原点と共有している場合、家族関係は兄弟とされ、
 *      その序列はおそらくパーサの実装に拠る。$(BR)
 *      現状、ファイル上で先に出現したマテリアル名を持つ方が兄になっていると思われる。$(BR)
 *
 *   ボーンが輪のように閉じ、序列をつけられない場合、<del>null を返す。</del>
 *   輪を成しているボーンのうち、ファイル上で最初に出現したボーンと最後のボーンの間で親子関係を切っている。
 */
private void fillBoneInfosFamily( BoneInfo[int] binfo )
{
	void fillChildren( int m, BoneInfo bt )
	{
		loop: foreach( om, one ; binfo )
		{
			if( bt is one ) continue;
			if( bt.tip == one.zero && null is one.parent ){ bt.children ~= one; one.parent = bt; continue; }
			if( bt.zero == one.zero && m < om && null is one.big_brother ) { one.big_brother = bt; bt.brothers ~= one;  continue; }
			foreach( ft ; bt.floating_tip )
			{
				if( ft == one.zero && null is one.parent ){ bt.children ~= one; one.parent = bt; continue loop; }
			}
		}
	}
	foreach( m, one ; binfo ) fillChildren( m, one );
}

/*FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF*\
|*|                              sortBoneIinfo                               |*|
\*FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF*/
// 親子関係でソート。ルートボーンが先頭にくる。
// 先祖 < 子孫 になるようにする。イトコ関係のボーンの順列は未定義
private BoneInfo[] sortBoneInfo( BoneInfo[int] binfo, ref BoneInfo[] root )
{
	BoneInfo[] child, all;

	foreach( one ; binfo ) if( null is one.parent && null is one.big_brother ) root ~= one;

	void addChild( BoneInfo bi )
	{
		child ~= bi.children;
		child ~= bi.brothers;
		foreach( c ; bi.children ) addChild( c );
		foreach( b ; bi.brothers ) addChild( b );
	}

	foreach( one ; root ) addChild( one );
	all = root ~ child;
	foreach( i, one ; all ) one.id = i;
	return all;
}

/*############################################################################*\
|*#                                                                          #*|
|*#                              analyze anchor                              #*|
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
	void ready(VERTEX)( VERTEX[] vertex, BoneInfo bi, InfluenceSet[][] influence )
	{
		auto arr = Arrowf( [ 0.0f, 0, 0 ], Vector3f( 0, 0, 1 ) * bi.bone.localize );
		float max_x, max_y, max_z, min_x, min_y, min_z;
		max_x = max_y = max_z = -float.max;
		min_x = min_y = min_z = float.max;
		Vector3f vec;

		alias pos_attr = AttributeConnector!( VERTEX, VLD_POSITION );
		foreach( i, v ; vertex )
		{
			arr.p = pos_attr( v );
			auto inf = arr.depthIn( this.vertex, faces );
			if( 0 < inf )
			{
				influence[ i ] ~= InfluenceSet( bi, inf );
				vec = bi.bone.localize * pos_attr( v );
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
private void setInfluencesSlot(VERTEX)( Bone[] bones, BoneInfo[int] binfo, AnchorFace[int] anchors, VERTEX[] vertex
                                      , SdefPart skin )
{
	alias matrix_attr = AttributeConnector!( VERTEX, VLD_MATRIX );
	alias influence_attr = AttributeConnector!( VERTEX, VLD_INFLUENCE );

	static if( matrix_attr.active )
	{
		static assert( influence_attr.active );
		static assert( is( matrix_attr.TYPE : int[] ) && is( influence_attr.TYPE : float[] ) && matrix_attr.TYPE.length == influence_attr.TYPE.length );
		enum COUNT = matrix_attr.TYPE.length;
	}
	else enum COUNT = 1;

	// 影響度を設定
	InfluenceSet[][] variable_influences = new InfluenceSet[][vertex.length];
	foreach( key, bi ; binfo )
	{
		if( key !in anchors ) continue;
		anchors[key].ready( vertex, bi, variable_influences );
	}
	catchLonelyVertex( vertex, binfo, variable_influences );
	auto ninf = normalizeInfluences!COUNT( variable_influences );

// ┌───── dummy
// │  ┌─── neighbours.id
// │  │   ┌- 対象 Bone.id
	int[int][int] neighbours;
	void addFace( Bone b, ref MikotoMaterial material, uint[] idxs )
	{
		if     ( 0 == b.parts.length || b.parts[$-1].vertex_id != skin.vertex_id )
			b.parts ~= SdefPart( skin.vertex_id, [ SdefFace( material, idxs ) ] );
		else if( 0 == b.parts[$-1].faces.length || b.parts[$-1].faces[$-1].material !is material )
			b.parts[$-1].faces ~= SdefFace( material, idxs );
		else
			b.parts[$-1].faces[$-1] ~= idxs;

		// 干渉しあうアンカーの列挙
		foreach( i ; idxs )
		{
			for( size_t j = 0 ; j < COUNT ; j++ )
			{
				if     ( null is ninf[i][j] ) break;
				else if( ninf[i][j].id != b.id ) neighbours[ b.id ][ ninf[i][j].id ] = 1;
			}
		}
	}

	int bidx = -1;
	foreach( face ; skin.faces )
	{
		for( size_t i = 0, j = 0 ; i+3 <= face.length ; i+=3 )
		{
			assert( null !is ninf[ face[i] ][0].bi );
			auto mlb = ninf[face[i]][0].id;
			if     ( mlb < 0 || bones.length <= mlb ) continue;
			else if( i == j ) bidx = mlb;
			else if( face.length < i+6 ) { addFace( bones[bidx], face.material, face[ j .. i + 3 ] ); break; }
			else if( bidx != mlb )
			{
				addFace( bones[bidx], face.material, face[ j .. i ] );
				j = i;
				bidx = mlb;
			}
		}
	}

	foreach( id, neighbour ; neighbours )
	{
		foreach( n, dummy ; neighbour ) bones[id].neighbours ~= bones[n];
	}

	static if( matrix_attr.active )
	{
		foreach( i, ref one ; vertex )
		{
			for( size_t j = 0 ; j < COUNT ; j++ )
			{
				if( null is ninf[i][j].bi ) break;
				matrix_attr( one )[j] = ninf[i][j].id;
				influence_attr( one )[j] = ninf[i][j].influence;
			}
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
private void catchLonelyVertex(VERTEX)( VERTEX[] vertex, BoneInfo[int] binfo, InfluenceSet[][] influence )
{
	alias pos_attr = AttributeConnector!( VERTEX, VLD_POSITION );
	static assert( pos_attr.active );
	BoneInfo getNearestBone( ref const(pos_attr.TYPE) pos )
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
			auto nb = getNearestBone( pos_attr(vertex[i]) );
			if( null !is nb ) inf ~= InfluenceSet( nb, 1.0 );
		}
	}
}

/*FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF*\
|*|                           normalizeInfluences                            |*|
\*FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF*/
/*
 * 影響度の大きい方からCOUNT個を選択し、影響度を正規化(その頂点について合計すると 1 になるように)する。
 */
private InfluenceSet[COUNT][] normalizeInfluences( size_t COUNT )( InfluenceSet[][] inf )
{
	InfluenceSet[COUNT][] result = new InfluenceSet[COUNT][ inf.length ];
	float total;

	foreach( i, one ; inf )
	{
		sort!"a.influence >= b.influence"( one );
		total = 0.0;
		for( size_t j = 0 ; j < COUNT && j < one.length ; j++ )
		{
			result[i][j] = one[j];
			total += one[j].influence;
		}
		if( 0.0 == total || float.nan is total ) continue;
		else total = 1 / total;

		for( size_t j = 0 ; j < COUNT ; j++ ) result[i][j].influence *= total;
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
/*/
	foreach( i, b ; bs.bsys.bones )
	{
		writeln( i, " : ", b.parts.length );
	}
//*/
}
