/** BoneSystem を動かす。
 * Version:      0.0012(dmd2.060)
 * Date:         2012-Aug-17 00:12:50
 * Authors:      KUMA
 * License:      CC0
 */
module sworks.mqo.mikoto_motion;

import sworks.compo.util.matrix;
import sworks.mqo.misc;
import sworks.mqo.mkm;
import sworks.mqo.bone_system;

/*CCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCC*\
|*|                               ActorMotion                                |*|
\*CCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCC*/
/**
 * ある BoneSystem に対する一連のモーション
 */
class ActorMotion
{
	TranslateMotion world_translate; /// キャラクタのワールド座標を決定する。
	RotateMotion world_rotate; /// ditto
	TranslateMotion translation; /// ルートボーンのみ平行移動がある。
	RotateMotion[] rotation; /// ルートボーン以外は回転運動のみ。
	float original_duration; /// 一連のモーションにかかる時間(sec)

	///
	this( float dur, TranslateMotion wt, RotateMotion wr, TranslateMotion tm, RotateMotion[] rm )
	{
		this.original_duration = dur;
		this.world_translate = wt;
		this.world_rotate = wr;
		this.translation = tm;
		this.rotation = rm;
	}

	/// BoneSystem にモーションを適用する。
	void attach( BoneSystem bs )
	{
		bs.world_translate = world_translate;
		bs.world_rotate = world_rotate;
		bs.root_translate = translation;
		assert( rotation.length == bs.bones.length );
		foreach( i, one ; bs.bones ) one.motion = rotation[i];
	}
}

/*FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF*\
|*|                         motionChunkToActorMotion                         |*|
\*FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF*/
/**
 * モーションチャンクから ActorMotion を得る。
 * Params:
 *   target_actor = 対象となるキャラの名前。これ以外のキャラ用のモーションは無視される。
 */
ActorMotion motionChunkToActorMotion( MotionChunk chunk, string target_actor, ref in BoneSet bs
                                    , string delegate(jstring) toUTF8  )
{
	float duration = cast(float)chunk.endframe / 60.0f;
	TranslateMotion wt;
	RotateMotion wr;
	TranslateMotion tm;
	RotateMotion[] rm;


	foreach( jkey, vec ; chunk.vector )
	{
		if( toUTF8( jkey ) == target_actor ) { wt = new TranslateMotion( vec.translation ); break; }
	}
	if( null is wt ) wt = new TranslateMotion();

	foreach( jkey, qtn ; chunk.quaternion )
	{
		if( toUTF8( jkey ) == target_actor ) { wr = new RotateMotion( qtn.rotation ); break; }
	}
	if( null is wr ) wr = new RotateMotion();
	
	MotionChunk motion;
	foreach( jkey, mot ; chunk.motion )
	{
		if( toUTF8( jkey ) == target_actor ) { motion = mot; break; }
	}
	if( null !is motion )
	{
		foreach( root_name ; bs.roots )
		{
			auto key = "j_".j ~ root_name;
			if( key in motion.vector ){ tm = new TranslateMotion( motion.vector[key].translation ); break; }
		}
		if( null is tm ) tm = new TranslateMotion();

		rm = new RotateMotion[ bs.bsys.bones.length ];
		foreach( key, q ; motion.quaternion )
		{
			if( key !in bs.bone_id ) continue;
			rm[ bs.bone_id[ key ] ] = new RotateMotion( q.rotation );
		}
		foreach( ref one ; rm ) if( null is one ) one = new RotateMotion();
	}

	return new ActorMotion( duration, wt, wr, tm, rm );
}



/*CCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCC*\
|*|                               MotionState                                |*|
\*CCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCC*/
/**
 * 現在のモーションの状態を格納する。
 */
class MotionState
{
	ActorMotion motion; /// モーション。
	bool is_stop; /// 停止状態にあるかどうか。
	float start, end;
	float current_frame; /// 現在何フレーム目か。[ 0.0, 1.0 ] で、1.0 でモーション終わり。
	float speed; /// 1ミリ秒で current_frame をいくら進めるか。

	MotionState next; /// 次のモーションの予定。

	this( ActorMotion motion, float start = 0.0, float end = 1.0, float sp = float.nan )
	{
		this.motion = motion;
		this.start = start;
		this.end = end;
		is_stop = false;
		current_frame = start;
		if( 0 < sp ) speed = sp;
		else speed = 0.001/motion.original_duration;
	}

	/**
	 * current_frame を更新する。$(BR)
	 * Params:
	 *   interval = 何ミリ秒分更新するか。
	 * Returns:
	 *   現在のフレーム。
	 */
	float update( uint interval )
	{
		if( !is_stop && current_frame < end ) current_frame += speed * cast(float)interval;
		return current_frame;
	}

	bool isComplete() const @property { return 1.0 <= current_frame; }
	void reset()
	{
		if( null !is next )
		{
			is_stop = false;
			current_frame = start;
		}
		else is_stop = true;
	}
}

/*FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF*\
|*|                               insertMotion                               |*|
\*FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF*/
/**
 * モーションのあるフレームに、別のモーションを挿入する。
 */
MotionState insertMotion( MotionState m1, ActorMotion a2, float f2s = 0.0, float f2e = 1.0
                                  , float speed = 1.0, float connection = 0.1 )
{
	auto m2 = new MotionState( generateMorphingMotion( m1.motion, m1.current_frame, a2, f2s, connection ) );
	auto m3 = new MotionState( a2, f2s, f2e );
	auto n = m1;
	for( ; null !is n.next && n.next !is n ; n = n.next ){ }
	auto m4 = new MotionState( generateMorphingMotion( a2, f2e, n.motion, 0, connection ) );
	m2.next = m3;
	m3.next = m4;
	m4.next = n;
	return m2;
}

/*FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF*\
|*|                          generateMorphingMotion                          |*|
\*FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF*/
/**
 * あるモーションのあるフレームから、別のモーションのあるフレームまで継げる。
 */
ActorMotion generateMorphingMotion( ActorMotion a1, float f1, ActorMotion a2, float f2, float dur )
{
	float[] f = [ 0.0, 1.0 ];
	TranslateMotion wtm;
	RotateMotion wrm;
	TranslateMotion tm;
	RotateMotion[] rm;

	wtm = new TranslateMotion( f, [ a1.world_translate[f1], a2.world_translate[f2] ] );
	wrm = new RotateMotion( f, [ a1.world_rotate[f1], a2.world_rotate[f2] ] );

	tm = new TranslateMotion( f, [ a1.translation[f1], a2.translation[f2] ] );
	rm = new RotateMotion[ a1.rotation.length ];

	for( size_t i = 0 ; i < rm.length ; i++ )
	{
		rm[i] = new RotateMotion( f, [ a1.rotation[i][f1], a2.rotation[i][f2] ] );
	}

	return new ActorMotion( dur, wtm, wrm, tm, rm );
}


////////////////////XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX\\\\\\\\\\\\\\\\\\\\
debug(mikoto_motion):
import std.stdio;
import sworks.mqo.parser;
import sworks.mqo.mqo;
import sworks.mqo.mikoto_model;
import sworks.mqo.mkm;
import sworks.compo.util.dump_members;

void main()
{
	auto mqo = load!MQObject( "dsan\\Dさん.mqo" );
	auto mm = mqoToMikotoModel( "Dさん.mqo", mqo );
	auto bs = mikotoModelToBoneSystem( mm );
	auto mkm = load!MKMotion( "dsan\\normal1.mkm" );

	auto am = motionChunkToActorMotion( mkm.motion["normal1".j], [68, -126, -77, -126, -15, 46, 109, 113, 111]
	                                  , bs );
	writeln( am.dump_members );
}