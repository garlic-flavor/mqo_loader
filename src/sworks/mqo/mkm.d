/** Mikoto モーションファイルフォーマット .mkm を読み込む。
 * Version:      0.0014(dmd2.062)
 * Date:         2013-Apr-06 01:08:29
 * Authors:      KUMA
 * License:      CC0
 */
module sworks.mqo.mkm;

import sworks.mqo.parser;
public import sworks.mqo.misc;


/*CCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCC*\
|*|                                 MKMotion                                 |*|
\*CCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCC*/
/// .mkm の最外側
class MKMotion
{
	/// .mkm ファイルのヘッダにヒットする。
	enum HEADER = `^Mikoto\s+Motion\s+Ver\s+(\d(?:\.\d)?)[\r\n]+`;
//	enum HEADER = "Mikoto Motion Ver";
	string version_string; /// 現在は "2" が入るはず。

	MotionChunk[jstring] motion; /// モーションチャンク。

}

/*CCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCC*\
|*|                               MotionChunk                                |*|
\*CCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCC*/
/// モーションチャンク
class MotionChunk : INamed
{
	jstring name_data; /// 名前は、mksとmkmで、または階層によって意味が違うようである。
	jstring name() @property const { return name_data; }

	int endframe;
	int loop;
	/**
	 * .mks ファイルでは MotionChunk は入れ子になる。$(BR)
	 * 1階層目 -&gt; モーションの名前
	 * 2階層目 -&gt; 対応するキャラクタ(3Dモデル)名
	 */
	MotionChunk[jstring] motion;
	/**
	 * 平行移動を記述する。$(BR)
	 * vector チャンクと quaternion チャンクは必ずしも一対一で対応するものではなく、
	 * どちらか片方という場合もある。$(BR)
	 */
	VectorChunk[jstring] vector;
	/**
	 * ボーンの原点まわりの回転移動を記述する。$(BR)
	 * 回転の初期位置は、ボーンのローカル座標の軸がワールド座標の軸と一致している状態であるようだ。$(BR)
	 * ここで、ボーンのローカル座標の軸とは、ボーンの斜辺の対角を原点とし、第二長辺をZ軸正の向きとし、
	 * 最短辺と第二長辺の外積をX軸正の向きと定めると、うまくいくようだ。
	 */
	QuaternionChunk[jstring] quaternion;

}

/*CCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCC*\
|*|                               VectorChunk                                |*|
\*CCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCC*/
/// ベクターチャンク
class VectorChunk : INamed, IOwnParser
{
	/**
	 * ベクターチャンク名は対象とするボーンの名前の先頭に "j_" を付加したものの様だが、なぜなのかは分らない。
	 */
	jstring name_data;
	jstring name() @property const { return name_data; }

	string class_data; ///
	string member; ///
	int endframe; ///
	string curve; /// mkm 内で現れる場合と、mks 内で現れる場合で、型がちがうようである。
	fTraf[] translation; /// 各キーフレーム毎の平行移動の状態を示す。

	// ベクターチャンクは書式が例外的なので特別なパーサを持つ。
	bool parser( ref Token token )
	{
		if( Token.TYPE.INT == token.type )
		{
			fTraf ft;
			token.chomp( ft );
			translation ~= ft;
		}
		return true;
	}

}

/*CCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCC*\
|*|                             QuaternionChunk                              |*|
\*CCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCC*/
/// クォータニオンチャンク
class QuaternionChunk : INamed, IOwnParser
{
	jstring name_data; ///
	jstring name() @property const { return name_data; }

	string class_data; ///
	string member; ///
	int endframe; ///
	string curve; ///
	fRotf[] rotation; ///

	//
	bool parser( ref Token token )
	{
		if( Token.TYPE.INT == token.type )
		{
			fRotf fr;
			token.chomp( fr );
			rotation ~= fr;
		}
		return true;
	}

}


////////////////////XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX\\\\\\\\\\\\\\\\\\\\
debug(mkm):
import std.stdio;
import sworks.mqo.parser;
import sworks.compo.util.dump_members;

void main()
{
	auto mkm = load!MKMotion( "dsan\\normal1.mkm" );
	writeln( mkm.dump_members );
}
