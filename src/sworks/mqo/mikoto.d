/** 機能の基本となる(予定)のクラス MikotoActor を提供する。
 * Version:      0.0012(dmd2.060)
 * Date:         2012-Aug-17 00:12:50
 * Authors:      KUMA
 * License:      CC0
 */
module sworks.mqo.mikoto;

import std.algorithm, std.exception, std.file, std.math, std.path;
import sworks.compo.util.matrix;
import sworks.mqo.parser_core;
import sworks.mqo.parser;
public import sworks.mqo.misc;
public import sworks.mqo.mqo;
public import sworks.mqo.mkm;
public import sworks.mqo.mks;
public import sworks.mqo.mikoto_model;
public import sworks.mqo.bone_system;
public import sworks.mqo.mikoto_motion;
debug import std.stdio;
debug import sworks.compo.util.dump_members;

/*############################################################################*\
|*#                                                                          #*|
|*#                            External Interface                            #*|
|*#                                                                          #*|
\*############################################################################*/
/*CCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCC*\
|*|                               MikotoActor                                |*|
\*CCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCC*/
/**
 * 最終的にはこのクラスに全ての機能がカプセル化される予定。
 */
class MikotoActor
{
	string name; /// キャラの名前
	BoneSystem bsys; /// ボーン

	ActorMotion[string] motion; /// モーション
	MotionState state;

	/// 中身は loadFromFiles にまる投げ
	this( string delegate(jstring) toUTF8, string[] files ... ) { loadFromFiles( toUTF8, files ); }

	/**
	 * ファイルからキャラクタを読み込む。
	 * Params:
	 *   toUTF8  = SHIFT-JIS -&gt; UTF-8 をするデリゲートを渡す。
	 *   files   = 対象とするファイル名。$(BR)
	 *             拡張子が .mqo の場合、Metasequoia ファイルとして読み込む。$(BR)
	 *             拡張子が .mks の場合、Mikoto Scene ファイルとして読み込む。$(BR)
	 *             拡張子が .mkm の場合、Mikoto Motion ファイルとして読み込む。$(BR)
	 *             ファイル名でなかった場合、キャラクタ名として扱われる。$(BR)
	 */
	void loadFromFiles( string delegate(jstring) toUTF8, string[] files ... )
	{
		BoneSet bset;
		foreach( file ; files )
		{
			auto ext = file.extension;

			if     ( "" == ext )
			{
				this.name = file;
			}
			else if( ".mqo" == ext )
			{
				if( 0 == this.name.length ) this.name = file.baseName;
				if( exists( file ) && null is bsys ) loadFromMQO( this, file, bset );
			}
			else if( ".mkm" == ext )
			{
				if( null is bset.bsys ) continue;
				loadFromMKM( this, file, bset, toUTF8 );
			}
			else if( ".mks" == ext )
			{
				loadFromMKS( this, file, bset, toUTF8 );
			}
		}

	}


	/// モーションを適用する。
	void attach( string motion_name )
	{
		assert( null !is bsys );
		if( null !is state )
		{
			auto nm = new MotionState( motion[ motion_name ] );
			nm.next = nm;
			state = new MotionState( generateMorphingMotion( state.motion, state.current_frame, nm.motion, 0, 1 ) );
			state.next = nm;
		}
		else
		{
			state = new MotionState( motion[ motion_name ] );
			state.next = state;
		}
		state.motion.attach( bsys );
	}

	/// ditto
	void attach( MotionState ms )
	{
		assert( null !is bsys );
		state = ms;
		if( null !is state ) state.motion.attach( bsys );
	}

	/// 新しいモーションを割り込ませる。
	void interrupt( string motion_name, float start = 0.0, float end = 1.0, float speed = 1.0, float c = 0.1 )
	{
		auto nm = motion.get( motion_name, null );
		if( null is nm ) return;
		attach( insertMotion( state, nm, 0.05, end, speed, c ) );
	}

	/// ボーンの変換行列を更新する。
	void update( uint interval )
	{
		assert( null !is bsys );
		if( null !is state )
		{
			bsys.update( state.update( interval ) );
			if( state.isComplete )
			{
				state = state.next;
				if( null !is state )
				{
					state.reset();
					state.motion.attach( bsys );
				}
			}
		}
	}


	/// 入力された OBB と当ってるボーンを返す。
	Bone[] collideBones( ref const(OBBox) box )
	{
		Bone[] result;
		foreach( bone ; bsys.bones )
		{
			if( bone.bbox.isCollide( box ) ) result ~= bone;
		}
		return result;
	}
}

//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\
//\\                                                                        //\\
//\\                                private                                 //\\
//\\                                                                        //\\
//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\
/*FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF*\
|*|                               loadFromMQO                                |*|
\*FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF*/
private void loadFromMQO( MikotoActor ma, string mqo_file, ref BoneSet bs )
{
	auto mqo = load!MQObject( mqo_file );
	auto mm = mqoToMikotoModel( mqo );
	bs = mikotoModelToBoneSet( mm );
	ma.bsys = bs.bsys;
}

/*FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF*\
|*|                               loadFromMKM                                |*|
\*FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF*/
private void loadFromMKM( MikotoActor ma, string file, ref BoneSet bs, string delegate(jstring) toUTF8 )
{
	auto mkm = load!MKMotion( file );
	foreach( motion_name, chunk ; mkm.motion )
	{
		auto m = motionChunkToActorMotion( chunk, ma.name, bs, toUTF8 );
		if( null !is m ) ma.motion[ toUTF8( motion_name ) ] = m;
	}
}


/*FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF*\
|*|                                loadFromMKS                               |*|
\*FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF*/
private void loadFromMKS( MikotoActor ma, string file, ref BoneSet bs, string delegate(jstring) toUTF8 )
{
	auto mks = load!MKScene( file );
	if( null is ma.bsys )
	{
		CharacterChunk cc;
		if( 0 == ma.name.length )
		{
			cc = mks.firstImportableCharacterChunk();
			ma.name = toUTF8( cc.name );
		}
		else cc = mks.getCharacterChunk( ma.name, toUTF8 );

		if( null !is cc && 0 < cc.import_data.length )
		{
			auto mqo = searchFile( toUTF8( cc.import_data ) );
			if( 0 < mqo.length ) loadFromMQO( ma, mqo, bs );
		}
	}

	assert( null !is ma.bsys );
	assert( 0 < ma.name.length );

	foreach( project ; mks.character )
	{
		foreach( motion_name, chunk ; project.motion )
		{
			auto m = motionChunkToActorMotion( chunk, ma.name, bs, toUTF8 );
			if( null !is m ) ma.motion[ toUTF8( motion_name ) ] = m;
		}
	}
}

