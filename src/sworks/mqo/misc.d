/** こまごましたのん。
 * Version:      0.0012(dmd2.060)
 * Date:         2012-Aug-17 00:12:50
 * Authors:      KUMA
 * License:      CC0
*/
module sworks.mqo.misc;

import std.algorithm, std.file, std.math, std.path;
import sworks.compo.util.matrix;
debug import std.stdio;

/*AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA*\
|*|                                 jstring                                  |*|
\*AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA*/
/**
 * SHIFT-JIS の格納に$(BR)
 * コンパイル時評価に向けて、文字コードの変換は遅延させる。
 */
alias immutable(byte)[] jstring;
/// suger
jstring j(T)( T[] str){ return cast(jstring)str; }
/// ditto
string c(T)( T[] jstr ){ return cast(string)jstr; }


/*SSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSS*\
|*|                                  Color3                                  |*|
\*SSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSS*/
/// アルファ値なし色情報
struct Color3(PRECISION)
{
	union
	{
		PRECISION[3] v;
		struct{ PRECISION r, g, b; }
	}
	alias v this;
	this( PRECISION[3] v ... ) { this.v[] = v[]; }
}
alias Color3!float Color3f;

/*SSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSS*\
|*|                                  Color4                                  |*|
\*SSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSS*/
/// アルファ値あり色情報
struct Color4(PRECISION)
{
	union
	{
		PRECISION[4] v = 0;
		struct{ PRECISION r, g, b, a; }
	}
	alias v this;
	this( in PRECISION[4] v ... ) { this.v[] = v[]; }
}
alias Color4!float Color4f;

/*SSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSS*\
|*|                              UVCoordination                              |*|
\*SSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSS*/
/// テクスチャ座標
struct UVCoordination(PRECISION)
{
	union
	{
		PRECISION[2] a;
		struct{ PRECISION u, v; }
	}
	alias a this;
	this( PRECISION[2] a ... ) { this.a[] = a[]; }
}
alias UVCoordination!float UVf;

/*SSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSS*\
|*|                            FramedTranslation                             |*|
\*SSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSS*/
/**
 * モーションの各キーフレームでの平行移動の状態を示す。$(BR)
 * ボーンの原点の初期位置からの移動量で表わされているようだ。$(BR)
 */
struct FramedTranslation(PRECISION)
{
	uint frame;
	Vector3!PRECISION vector;
}
alias FramedTranslation!float fTraf;

/*SSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSS*\
|*|                              FramedRotation                              |*|
\*SSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSS*/
/**
 * モーションの各キーフレームでの回転移動の状態を示す。$(BR)
 * 回転の初期位置は、ボーンのローカル座標の軸がワールド座標の軸と一致している状態であるようだ。$(BR)
 * ここで、ボーンのローカル座標の軸とは、ボーンの斜辺の対角を原点とし、第二長辺をZ軸正の向きとし、
 * 最短辺と第二長辺の外積をX軸正の向きと定めると、うまくいくようだ。$(BR)
 */
struct FramedRotation(PRECISION)
{
	int frame;
	Quaternion!PRECISION quaternion;
}
alias FramedRotation!float fRotf;


/*CCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCC*\
|*|                             TranslateMotion                              |*|
\*CCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCC*/
/**
 * 一連のモーションにおける平行移動を表す。$(BR)
 * フレームは [ 0.0, 1.0 ] の浮動小数点数で表す。
 */
class TranslateMotion
{
	Vector3f[] translation; /// キーフレームにおける移動量
	float[] frame; /// フレーム数

	this( fTraf[] ft = null )
	{
		frame = new float[ ft.length ];
		translation = new Vector3f[ ft.length ];
		float max_frame = 0 < ft.length ? ft[$-1].frame : 0;
		if( 0 < max_frame ) max_frame = 1 / max_frame;
		
		for( size_t i = 0 ; i < ft.length ; i++ )
		{
			frame[i] = ft[i].frame * max_frame;
			translation[i] = ft[i].vector;
		}
	}
	this( float[] f, Vector3f[] v ) { this.frame = f; this.translation = v; }
	this() { this.frame = [ 0f ]; this.translation = [ Vector3f() ]; }

	/**
	 * あるフレームにおける平行移動量を返す。
	 * Param:
	 *   f = [ 0, 1 ] で、0の時、初期ポーズ、1の時に最終ポーズとなるようにしてある。$(BR)
	 */
	Vector3f opIndex( float f )
	{
		for( size_t i = 0 ; i < frame.length ; i++ )
		{
			if     ( f <= frame[i] || frame.length <= i+1 ) return translation[i];
			else if( i+1 < frame.length && f < frame[i+1] )
				return interpolateLinear( translation[i], (f-frame[i])/(frame[i+1]-frame[i]), translation[i+1] );
		}
		return Vector3f();
	}
}


/*CCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCC*\
|*|                               RotateMotion                               |*|
\*CCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCC*/
/**
 * 一連のモーションにおける回転移動を表す。$(BR)
 * フレームは、[ 0.0, 1.0 ] の浮動小数点数で表す。$(BR)
 */
class RotateMotion
{
	Quaternionf[] quaternion; /// キーフレームにおける回転量
	float[] frame; /// [ 0, 1 ]

	this( fRotf[] fr = null )
	{
		frame = new float[ fr.length ];
		quaternion = new Quaternionf[ fr.length ];
		float max_frame = 0 < fr.length ? fr[$-1].frame : 0.0;
		if( 0 < max_frame ) max_frame = 1 / max_frame;

		for( size_t i = 0 ; i < fr.length ; i++ )
		{
			frame[i] = fr[i].frame * max_frame;
			quaternion[i] = fr[i].quaternion;
		}
	}

	this( float[] f, Quaternionf[] q ) { this.frame = f; this.quaternion = q; }
	this(){ this.frame = [ 0f ]; this.quaternion = [ Quaternionf() ]; }

	/**
	 * あるフレームにおけるクォータニオンを返す。$(BR)
	 * Params:
	 *   f = [ 0, 1 ] で、0の時、初期ポーズ、1の時に最終ポーズとなるようにしてある。$(BR)
	 *       後々、モーションの速度とか変えられるようにしたい。$(BR)
	 */
	Quaternionf opIndex( float f )
	{
		for( size_t i = 0 ; i < frame.length ; i++ )
		{
			if     ( f <= frame[i] || frame.length <= i+1 ) return quaternion[i];
			else if( i+1 < frame.length && f < frame[i+1] )
				return interpolateLinear( quaternion[i], (f-frame[i])/(frame[i+1]-frame[i]), quaternion[i+1] );
		}
		return Quaternionf();
	}
}

/*SSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSS*\
|*|                              Transformation                              |*|
\*SSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSS*/
/**
 * 座標軸を変換する。$(BR)
 * ボーンの姿勢を決定するのに使われる。$(BR)
 * コンストラクタに渡された3つの頂点から新しい座標軸を求める。$(BR)
 */
struct Transformation(PRECISION)
{
	Vector3!PRECISION translation; /// 旧座標での、新しい座標の原点の位置
	Quaternion!PRECISION rotation; /// 旧座標に対する、新しい座標の傾き

	this( Vector3!PRECISION t, Quaternion!PRECISION q ){ this.translation = t; this.rotation = q; }

	/**
	 * Params:
	 *   vertex = 3つの頂点からなり、以下の要領で新しい座標を定義する。$(BR)
	 *            <ul>
	 *              <li>vertex[0] は原点である。</li>
	 *              <li>3つの頂点は新しい座標の Y軸、Z軸を含む平面上にある。</li>
	 *              <li>vertex[0] から見て vertex[1] が Z軸正の向きである。</li>
	 *              <li>vertex[0] から見て vertex[2] は 新しい座標で、Z軸から Y の値が正の側にある。</li>
	 *            </ul>
	 */
	this( Vector3!PRECISION[3] vertex ... )
	{
		translation = -vertex[0];

		auto z = (vertex[1] - vertex[0]).normalizedVector;
		auto x = (vertex[2] - vertex[0]).cross(z).normalizedVector;
		auto zaxis = Vector3f( 0, 0, 1 );
		auto xaxis = Vector3f( 1, 0, 0 );
		rotation = z.getQuaternionTo( zaxis );
		x = rotation * x;
		rotation = x.getQuaternionTo( xaxis, zaxis ) * rotation;
	}

	/// 単位行列みたいなのを読み込む。
	void loadIdentity() { translation = Vector3f(); rotation = Quaternionf(); }

	/// もとの座標系へと変換する TransformationSet を返す。
	Transformation opUnary( string OP : "-" )() const
	{
		return Transformation( rotation * -translation, rotation.conjugate );
	}

	/// 新しい座標系へと変換する行列を返す。
	Matrix4!PRECISION toMatrix() @property const
	{
		return rotation.toMatrix * Matrix4f.translateMatrix( translation );
	}

	/// もとの座標系へと変換する行列を返す。
	Matrix4!PRECISION toInverseMatrix() @property const
	{
		return Matrix4f.translateMatrix( -translation ) * rotation.conjugate.toMatrix;
	}

	/// 変換を追加する。行列と同じで、左から追加する。
	Transformation opBinary( string OP : "*" )( in Transformation ts ) const
	{
		return Transformation( (ts.rotation.conjugate * translation) + ts.translation, rotation * ts.rotation );
	}
	/// ditto
	ref Transformation opOpAssign( string OP : "*" )( in Transformation ts )
	{
		translation = (ts.rotation.conjugate * translation) + ts.translation;
		rotation *= ts.rotation;
		return this;
	}

	/// 回転だけ追加する。
	Transformation opBinary( string OP : "*" )( in Quaternion!PRECISION q ) const
	{
		return Transformation( q.conjugate * translation, rotation * q );
	}
	/// ditto
	ref Transformation opOpAssign( string OP : "*" )( in Quaternion!PRECISION q )
	{
		translation = (q.conjugate * translation);
		rotation *= q;
		return this;
	}

	/// 平行移動を追加する場合は演算子が "+" なので注意。
	Transformation opBinary( string OP : "+" )( in Vertex3!PRECISION v ) const
	{
		return Transformation( translation + v, rotation );
	}
	/// ditto
	ref Transformation opOpAssign( string OP : "+" )( in Vector3!PRECISION v )
	{
		translation += v;
		return this;
	}

	/// 変換を v に対して実行する。
	Vector3!PRECISION opBinary( string OP : "*" )( in Vector3!PRECISION v ) const
	{
		return rotation * ( translation + v );
	}

	Vector3!PRECISION opBinaryRight( string OP : "*" )( in Vector3!PRECISION v ) const
	{
		return ( rotation.conjugate * v ) - translation;
	}
}
alias Transformation!float Tranf;

unittest
{
	auto t1 = Tranf( Vector3f( 1, 2, 3 )
	               , Quaternionf.rotateQuaternion( PI_2, Vector3f( 3, 2 , 80 ).normalizedVector ) );
	auto v1 = V3( 1, 2, 3 );
	auto v2 = t1 * v1;
	auto v3 = (-t1) * v2;
	assert( aEqual( v1[], v3[] ) );
}

unittest
{
	auto t1 = Tranf( Vector3f( 1, 2, 3 )
	               , Quaternionf.rotateQuaternion( PI_2, Vector3f( 3, 2 , 80 ).normalizedVector ) );
	auto v1 = V3( 1, 2, 3 );
	auto v2 = t1 * v1;
	auto v3 = v2 * t1;
	assert( aEqual( v1[], v3[] ) );
}

unittest
{
	auto t1 = Tranf( Vector3f( 1, 2, 3 )
	               , Quaternionf.rotateQuaternion( PI_2, Vector3f( 3, 2 , 80 ).normalizedVector ) );
	auto t2 = Tranf( Vector3f( 1, 0, 0 )
	               , Quaternionf.rotateQuaternion( PI_2, Vector3f( 10, -1, 2 ).normalizedVector ) );
	auto t3 = t1 * t2;
	auto v1 = Vector3f( 20, 20, 20 );
	auto v2 = t1 * (t2 * v1);
	auto v3 = t3 * v1;
	assert( aEqual( v2[], v3[] ) );

	auto mat = t1.toMatrix * t2.toMatrix;
	auto v4 = mat * v1;
	assert( aEqual( v2[], v4[] ) );
}

/*SSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSS*\
|*|                                  OBBox                                   |*|
\*SSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSS*/
/// 当り判定用
struct OBBox
{
	Tranf localize; /// 自分の座標系に変換する。
	private Vector3f _width2;
	private float max_width2, min_width2; /// バウンディングサークルによる簡易当り判定で高速化。

	/// 重心が原点にくるようになっているはずなので、頂点座標は一つでよい。
	ref const(Vector3f) width2() const @property { return _width2; }
	ref Vector3f width2( in Vector3f w ) @property
	{
		_width2 = w;
		max_width2 = w.length;
		min_width2 = min( w.x, min( w.y, w.z ) );
		return _width2;
	}

	/// 入力されたベクトルに影を投影し、その長さ(の半分)を求める。
	float shadowLength2( ref const(Vector3f) v ) const
	{
		return abs( v.x * _width2.x ) + abs( v.y * _width2.y ) + abs( v.z * _width2.z );
	}

	private float shadowLength2XY( ref const(Vector3f) v ) const
	{
		return abs( v.x * _width2.x ) + abs( v.y * _width2.y );
	}
	private float shadowLength2YZ( ref const(Vector3f) v ) const
	{
		return abs( v.y * _width2.y ) + abs( v.z * _width2.z );
	}
	private float shadowLength2ZX( ref const(Vector3f) v ) const
	{
		return abs( v.x * _width2.x ) + abs( v.z * _width2.z );
	}

	private bool _checkCollideByOwnAxis( ref const(Vector3f) distVec, ref const(OBBox) ob ) const
	{
		Vector3f v;
		Vector3f dv = localize.rotation * distVec;
		Quaternionf q = ob.localize.rotation * localize.rotation.conjugate;
		v = q * Vector3f( 1, 0, 0 );
		if( _width2.x + ob.shadowLength2( v ) < dv.x.abs ) return false;
		v = q * Vector3f( 0, 1, 0 );
		if( _width2.y + ob.shadowLength2( v ) < dv.y.abs ) return false;
		v = q * Vector3f( 0, 0, 1 );
		if( _width2.z + ob.shadowLength2( v ) < dv.z.abs ) return false;
		return true;
	}

	private bool _checkCollideBy9Axis( ref const(Vector3f) distVec, ref const(OBBox) ob ) const
	{
		Vector3f v, v1, v2, vx, vy, vz, v1x, v1y, v1z, v2x, v2y, v2z;
		Quaternionf q1 = localize.rotation.conjugate;
		Quaternionf q2 = ob.localize.rotation.conjugate;
		vx = Vector3f( 1, 0, 0 ); vy = Vector3f( 0, 1, 0 ); vz = Vector3f( 0, 0, 1 );
		v1x = q1 * vx;
		v2x = q2 * vx;
		v = v1x.cross( v2x );
		v1 = localize.rotation * v;
		v2 = ob.localize.rotation * v;
		if( shadowLength2YZ(v1) + ob.shadowLength2YZ(v2) < distVec.dot(v).abs ) return false;
		v2y = q2 * vy;
		v = v1x.cross( v2y );
		v1 = localize.rotation * v;
		v2 = ob.localize.rotation * v;
		if( shadowLength2YZ(v1) + ob.shadowLength2ZX(v2) < distVec.dot(v).abs ) return false;
		v2z = q2 * vz;
		v = v1x.cross( v2z );
		v1 = localize.rotation * v;
		v2 = ob.localize.rotation * v;
		if( shadowLength2YZ(v1) + ob.shadowLength2XY(v2) < distVec.dot(v).abs ) return false;

		v1y = q1 * vy;
		v = v1y.cross( v2x );
		v1 = localize.rotation * v;
		v2 = ob.localize.rotation * v;
		if( shadowLength2ZX(v1) + ob.shadowLength2YZ(v2) < distVec.dot(v).abs ) return false;
		v = v1y.cross( v2y );
		v1 = localize.rotation * v;
		v2 = ob.localize.rotation * v;
		if( shadowLength2ZX(v1) + ob.shadowLength2ZX(v2) < distVec.dot(v).abs ) return false;
		v = v1y.cross( v2z );
		v1 = localize.rotation * v;
		v2 = ob.localize.rotation * v;
		if( shadowLength2ZX(v1) + ob.shadowLength2XY(v2) < distVec.dot(v).abs ) return false;

		v1z = q1 * vz;
		v = v1z.cross( v2x );
		v1 = localize.rotation * v;
		v2 = ob.localize.rotation * v;
		if( shadowLength2XY(v1) + ob.shadowLength2YZ(v2) < distVec.dot(v).abs ) return false;
		v = v1z.cross( v2y );
		v1 = localize.rotation * v;
		v2 = ob.localize.rotation * v;
		if( shadowLength2XY(v1) + ob.shadowLength2ZX(v2) < distVec.dot(v).abs ) return false;
		v = v1z.cross( v2z );
		v1 = localize.rotation * v;
		v2 = ob.localize.rotation * v;
		if( shadowLength2XY(v1) + ob.shadowLength2XY(v2) < distVec.dot(v).abs ) return false;

		return true;
	}


	/// 当り判定をする。
	bool isCollide( ref const(OBBox) ob ) const
	{
		auto distVec = ob.localize.translation - localize.translation;

		// まずはバウンディングサークルでチェック。
		auto distSq = distVec.lengthSq;
		if( pow( max_width2 + ob.max_width2, 2 ) < distSq ) return false;
		if( distSq < pow( min_width2 + ob.min_width2, 2 ) ) return true;

		if( !_checkCollideByOwnAxis( distVec, ob ) ) return false;
		if( !ob._checkCollideByOwnAxis( distVec, this ) ) return false;
		if( !_checkCollideBy9Axis( distVec, ob ) ) return false;
		return true;
	}
}

/*FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF*\
|*|                                searchFile                                |*|
\*FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF*/
/**
 * ファイルを探す。
 *
 * Params:
 *   filename = ファイル名
 *   bases    = 検索するパス
 */
string searchFile( string filename )
{
	for( ; 0 < filename.length ; )
	{
		if( exists( filename ) ) return filename;
		if( findSkip( filename, "\\" ) ) continue;
		if( findSkip( filename, "/" ) ) continue;
		break;
	}
	assert( 0, filename ~ " is not detected." );
	return null;
}

/*SSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSS*\
|*|                                 HitState                                 |*|
\*SSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSS*/
/// 直線とポリゴンの交差状態を格納する。
struct HitState(PRECISION)
{
	/// 点とポリゴンとの交点の距離
	PRECISION distance = PRECISION.max;

	/**
	 * 点から見てポリゴンが時計回りの時 -&gt; true
	 * OpenGL系では、点から見てポリゴンが時計回りの時は、その点はポリゴンの裏側にある。
	 */
	bool clockwise = false;
}

/*FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF*\
|*|                                crossState                                |*|
\*FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF*/
/**
 * 無限直線 arr が、TRIANGLE を形成する face、 vertex と交差するか、どう交差するか？(表から？裏から？)を判定している。$(BR)
 * 点 arr.p が TRIANGLE表面上にあり、直線 arr.v がポリゴン平面と平行の場合、
 * 直線は「TRIANGLE表から」「交差」と判定される。$(BR)
 * 点 arr.p が TRIANGLE表面上になく、直線 arr.v が TRIANGLE表面と平行にTRIANGLE表面上を通る場合、直線は「交差なし」と判定される。$(BR)
 * それ以外の場合、TRIANGLE表面、境界および頂点上は「交差」と判定される。$(BR)
 *
 * Params:
 *   hs     = hs に予め収められている距離より近かった場合のみ、これを更新する。$(BR)
 *            表裏が同じ距離にあった場合、表を優先する。$(BR)
 *   arr    = 調べたい直線。arr.v は正規化されているものとする。$(BR)
 *            正規化されていない場合、表裏判定は同じだが hs.dist の値はデタラメになる。$(BR)
 *   face   = TRIANGLEを定義するインデックス配列$(BR)
 *   vertex = TRIANGLEを成形する頂点配列$(BR)
 * Throws:
 *   face.length < 3 もしくは face が示す先より vertex が短かかった場合、 Range violation が投げられる。
 */
void crossState(PRECISION)( ref HitState!PRECISION hs, ref const(Arrow!PRECISION) arr, in uint[] face
                          , in Vector3!PRECISION[] vertex )
{
	Vector3f v1, v2, v3, c1, c2, c3, v12, v23, v31;
	PRECISION d, c12, c23, c31;
	PRECISION dist = PRECISION.max;
	v1 = vertex[ face[0] ] - arr.p;
	v2 = vertex[ face[1] ] - arr.p;
	v3 = vertex[ face[2] ] - arr.p;
	c1 = arr.v.cross( v1 );
	c2 = arr.v.cross( v2 );
	c3 = arr.v.cross( v3 );

	// ポリゴンと無限直線が、交差すると仮定する。………………… (1)
	// 仮定(1) より、c12、c23、c31 の符号は同じである。
	// 符号がちがう場合、仮定(1) に反するので、交差していない。
	c12 = c1.cross( c2 ).dot( arr.v );
	c23 = c2.cross( c3 ).dot( arr.v );
	if( ( c12 * c23 ) < 0 ) return;
	c31 = c3.cross( c1 ).dot( arr.v );
	if( ( c12 * c31 ) < 0 ) return;
	if( ( c23 * c31 ) < 0 ) return;

	// 仮定(1) が満たされたので、交差している。

	if( 0 == c12 && 0 == c23 && 0 == c31 ) // 点 arr.p がポリゴン平面上にある。
	{
		// 点 arr.p がポリゴン面上にある場合はヒット、でなければスルー
		v12 = v1.cross( v2 );
		v23 = v2.cross( v3 );
		if( v12.dot( v23 ) < 0 ) return;
		v31 = v3.cross( v1 );
		if( v23.dot( v31 ) < 0 ) return;

		dist = 0;
		d = 0;
	}
	else // 直線はポリゴンと交差
	{
		alias v12 v21;
		alias v23 nc213;
		v21 = v2 - v1;
		v31 = v3 - v1;
		nc213 = v21.cross( v31 ).normalizedVector;
		d = v1.dot( nc213 );
		dist = abs( d / arr.v.dot( nc213 ) );
	}
	if     ( dist < hs.distance )
	{
		hs.distance = dist;
		hs.clockwise = 0 < d; // 点から見えるのは裏か表か？ 0 <= d に書き替えると境界上がポリゴン内となる。
	}
	else if( dist == hs.distance ) // 同じ距離だった場合は表優先。これはメッシュの角などで起り得る。
	{
		hs.clockwise = hs.clockwise && 0 < d;
	}
}


/*FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF*\
|*|                                 depthIn                                  |*|
\*FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF*/
/**
 * 点 p が、メッシュの内側にあるかどうか？どの位の深さにあるか？を測定する。$(BR)
 * メッシュは閉じており、(OpenGL的に)表裏が正しいと仮定する。$(BR)
 * ( OpenGL では反時計回り順のポリゴンが表 )$(BR)
 * 任意方向での最寄りのポリゴンの裏が見えているかどうかを判定している。$(BR)
 * 裏が見えていれば、点はメッシュの内にある。$(BR)
 * 境界上は外側となる。$(BR)
 *
 * Params:
 *   arr    = arr.p が対象の点。arr.v が、どの方向での深さを調べるかを示す。
 *   vertex = メッシュを構成する。
 *   index  = メッシュを定義する。
 * Returns:
 *   深さが返る。点がメッシュに含まれなかった場合は、負の数が返る。
 */
PRECISION depthIn(PRECISION)( in Arrow!PRECISION arr, in Vector3!PRECISION[] vertex, uint[] index )
{
	HitState!PRECISION hs;
	for( size_t i = 0 ; i+3 <= index.length ; i+=3 )
	{
		hs.crossState( arr, index[ i .. $ ], vertex );
	}
	return hs.clockwise ? hs.distance : -hs.distance;
}

unittest
{
	auto vert = [ Vector3f( -1, 1, 1 ), Vector3f( 1, 1, 1 ), Vector3f( 1, 1, -1 ), Vector3f( -1, 1, -1 )
	            , Vector3f( -1, -1, 1 ), Vector3f( 1, -1, 1 ), Vector3f( 1, -1, -1 ), Vector3f( -1, -1, -1 ) ];
	uint[] idx = [ 0, 4, 5, 0, 5, 1, 0, 1, 2, 0, 2, 3, 0, 3, 7, 0, 7, 4
	             , 6, 2, 1, 6, 1, 5, 6, 5, 4, 6, 4, 7, 6, 7, 3, 6, 3, 2 ];

	assert( 0 < [ 0, 0, 0 ].depthIn!float( vert, idx ) );
	assert( 0 < [ 0.9, 0.9, -0.7 ].depthIn!float( vert, idx ) );
	assert( 0 < [ 0.9, 0.9, 0.9 ].depthIn!float( vert, idx ) );
	assert( 0 < [ -0.9, 0.9, 0.9 ].depthIn!float( vert, idx ) );
	assert( 0 >= [ -1.0, 1.0, 1.0 ].depthIn!float( vert, idx ) );
	assert( 0 >= [ 1.0, 1.0, 1.0 ].depthIn!float( vert, idx ) );
	assert( 0 >= [ 1.0, 0.0, 0.0 ].depthIn!float( vert, idx ) );
	assert( 0 >= [ 0.0, 10, 0.0 ].depthIn!float( vert, idx ) );

}

////////////////////XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX\\\\\\\\\\\\\\\\\\\\

debug(mqo_util):
import std.stdio;

version(unittest) void main()
{
	writeln( "unittest is complete." );
}