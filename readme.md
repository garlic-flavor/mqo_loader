# はじめにお読み下さい。 - MQO_Loader - #

これは [Metasequoia](http://www.metaseq.net/metaseq/ "Metasequoia")ファイルを読み込む為のプログラムです。

同梱のサンプルは 32bit Windows 用バイナリです。

実行には [SDL2](http://www.libsdl.org/ "SDL") と [OpenGL](http://www.opengl.org/ "OpenGL") が必要です。

- [569](http://toro.2ch.net/test/read.cgi/tech/1329714331/569 "569")さんのモデルを表示するためだけに作りました。
- [574](http://toro.2ch.net/test/read.cgi/tech/1329714331/574 574) さんの[ゲーム作る流れ](http://sourceforge.jp/projects/d-action/wiki/FrontPage "D言語でアクションゲームでも作ってみる？") に賛同するものです。


## ドキュメント ##
- [ドキュメント]( ./doc/index.html "ドキュメント")

(※ Opera11.64 Iron18 では見ることができませんでした。IE8 でも一部機能が使えませんでした。)


## ライセンス ##

ライセンスは [CC0](http://creativecommons.org/publicdomain/zero/1.0/ "CC0") です。

まあつっても NYSL やら Public Domain となにがチガウのか知りませんけど。


スレでライセンスについて言及があったので、私の理解している範囲で補足しておきます。

- import、lib フォルダ内のもの  
  Derelict は Boost ライセンスです。.libに関して制約はないようです。
  .diファイルはコンパイラの生成物でありながら object code ではないので微妙すぎて正直よくわかりません。
  とりあえず、[LICENSE.derelict.txt](LICENSE.derelict.txt "LICENSE") を置きましたので、それで許して。

- libiconv-2.dll  
  これは LGPL です。これも DLL 状態での配布には制限がないです。

- SDL2.dll, SDL2_image.dll  
  zlib ライセンスです。バイナリ配布には制限がないようです。

- libjpeg-8.dll  
  IJG のコードを利用していることを明記している限りにおいては制限はないようです。

- 初代Dさん.mqo  
  これは [569](http://toro.2ch.net/test/read.cgi/tech/1329714331/569 "569") さんから NYSL の宣言がありましたので、私もそれに従います。

- dsan フォルダ内のもの  
  これは、[637](http://toro.2ch.net/test/read.cgi/tech/1329714331/637 "637") さんの著作物です。ライセンスは NYSL Version 0.9982 と宣言されていますので私もそれに従います。

- それ以外全部  
  CC0 の適用により、私が放棄可能な全ての権利を放棄しましたので Public Domain です。


まあ、およそ好きに使っていただいていいだろうということになろうかと思います。<br/>


## 連絡先 ##

バグ、要望などありましたら、D言語スレに書いていただくか、スレチになるようなら

[sweatygarlic@yahoo.co.jp](mailto:sweatygarlic@yahoo.co.jp "メールアドレス")

まで連絡いただけると、がんばります。


## 更新履歴 ##

- 2012/08/17 ver 0.0013(dmd2.060)  
  github デビュー
