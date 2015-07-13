# NicoliveIo [![NPM version][npm-image]][npm] [![Build Status][travis-image]][travis] [![Coverage Status][coveralls-image]][coveralls]

> ニコニコ生放送のコメントサーバーの寄生サーバー

## インストール

```bash
$ npm install nicolive.io --save
```

## なぜ？

[ニコニコ生放送のコメントサーバーはtcpネットワークを使用して受信できます](http://qiita.com/59naga/items/0a22e30f019aaef683e4#%E3%83%97%E3%83%AC%E3%82%A4%E3%83%A4%E3%83%BC%E3%81%B8%E6%8E%A5%E7%B6%9A%E3%81%99%E3%82%8B)が、ブラウザには標準で搭載されているものがありません（多くは非標準で、ユーザーに実験機能をONにするなど、特殊の操作を強いるものが殆どです）。

このモジュールでは、ユーザーに代行してコメントサーバーに接続し、受信したxmlをパースして、socket.ioを介してユーザーへ通知します。webブラウザでコメントビューアを制作する人は、クロスドメイン制限を無視して、コメントサーバーへアクセスすることが可能になります。

### 課題

従来のコメントビューアと同じく、ブラウザに埋め込まれた[userSession](#userSession)をクッキーから取得する手段が必要です。
このモジュールでは、userSessionを取得していることを前提にしており、ブラウザ側のユーティリティを一切提供しません。

### デモ

[![](https://cloud.githubusercontent.com/assets/1548478/8640887/ae278f0c-2942-11e5-84cf-24604ec7f86c.png)](https://github.com/59naga/nicolive.berabou.me)

Angular-Materialを使用したデモです。

# API

## class `NicoliveIo` constructor(requestListener) -> nicoliveIo

`nicolive.io`をrequireすると、__socket.ioクラスを継承__した、`nicoliveIo`インスタンスと、`NicoliveIo`クラスを返します。

```js
var nicoliveIo= require('nicolive.io');
var NicoliveIo= require('nicolive.io').NicoliveIo;

console.log(nicoliveIo.__proto__.__proto__);
// [
//  'checkRequest',
//  'serveClient',
//  'set',
//  'path',
//  'adapter',
//  'origins',
//  'attach',
//  'listen',
//  'attachServe',
//  'serve',
//  'bind',
//  'onconnection',
//  'of',
//  'close',
//  'on',
//  'to',
//  'in',
//  'use',
//  'emit',
//  'send',
//  'write',
//  'json'
// ]

console.log(nicoliveIo instanceof NicoliveIo);
// true
```

`NicoliveIo`コンストラクタの第一引数に任意の`requestListener`を渡すことで、`socket.io`が補足しなかったrequestイベントを、渡した`requestListner`で受信できます。
以下は例では、Express4を`requestListner`に使用して、socket.ioサーバーと静的ファイルサーバーの両方を`http://localhost:59798`上に起動します。

```bash
$ npm install express --save

$ mkdir public
$ echo 'nicolive.io is available' > public/index.html

$ node app.js
# Listen at http://localhost:59798
```

`app.js`

```js
// Dependencies
var express= require('express');
var NicoliveIo= require('nicolive.io').NicoliveIo;

// Setup express
var app= express();
app.use(express.static('public'));

// Setup nicolive.io
var server= new NicoliveIo(app);

// Boot
server.listen(59798,function(){
  console.log('Listen at http://localhost:59798');
});
```

## nicoliveIo.listen(port,callback)

指定portでサーバーを起動します。callback関数を渡した場合、起動が完了したときに呼び出します。

## nicoliveIo.close(callback)

サーバーをショットダウンします。callback関数を渡した場合、ショットダウンが完了したときに呼び出します。

## nicoliveIo.on('connection',callback(clientSocket))

サーバーへ接続に成功したclientのEventEmitterインスタンスを、callback関数に渡します。
NicoliveIoはclientと接続が確立した時に、自動でイベントを追加します。追加するイベントは下記のとおりです。

### clientSocketEvent:`auth`

clientからuserSessionを受け取り、getplayerstatusへアクセスします。userSessionが有効であれば`authorized`イベントを、不正であれば`error`イベントを送信します。

### clientSocketEvent:`view`

clientからcannelIdを受け取り、getplayerstatusを経由してtcpでコメントに接続します。接続に成功すると、NicoliveIoはコメントサーバーから受信したxmlを解析し、解析結果でclientに送信し続けます。

接続中、送信するイベントは３種類あります：

* `thread`イベント:{resultcode,last_res,ticket,...} 接続したコメントサーバーの情報、接続が成功した時、はじめに１度だけイベントを発行する。resultcodeが'0'なら成功、それ以外なら失敗。失敗コードの詳細はresultcodeで検索してください。
* `chat`イベント:{'thread','vpos','date','date_usec','user_id','premium','no','text'} コメント・運営コメント・広告コメントのパース結果
* `chat_result`イベント:{{chat_attributes...},status} clientSocketEvent:`comment`を参照。statusが0であれば、コメントは受理されています

### clientSocketEvent:`comment`

clientにauthorizedイベントを送信済みであれば、コメントします。
コメントの結果を`chat_result`イベントでclientに送信します。

### clientSocketEvent:`error`

サーバー側で発生した例外をこのイベントで補足し、clientに`warn`イベントを送信します。

### clientSocketEvent:`disconnect`

clientがdisconnectメソッドを実行すると、サーバーはただちにtcpを切断します。

## `window.io`

クライアントは、まず初めにsocket.ioの依存ファイルである/socket.io/socket.io.jsを読み込む必要があります。以下はportを59798でサーバーを起動した場合の例です。

```html
<script src="http://localhost:59798/socket.io/socket.io.js"></script>
<script>
console.log(io);// function
</script>
```

### io.connect(url) -> serverSocket

以下のような順序でサーバーへイベントを送信することで、コメントをリアルタイムに受信します。

```html
<script src="http://localhost:59798/socket.io/socket.io.js"></script>
<script>
var userSession= 'user_session_000000_0000000000000000000000000000000000000000000000000000000000000000';

var serverSocket= io.connect();
serverSocket.on('connect',function(){
  console.log('connected');

  serverSocket.emit('auth',userSession);
});
serverSocket.on('authorized',function(debugPlayerStatus){
  console.log('authorized',debugPlayerStatus);

  serverSocket.emit('view','nsen/hotaru');
});

serverSocket.on('getplayerstatus',function(playerStatus){
  console.log('getplayerstatus',playerStatus);
});
serverSocket.on('thread',function(thread){
  console.log('thread',thread);

  serverSocket.emit('comment','てすてすてす');
});

serverSocket.on('chat',function(chat){
  console.log('chat',chat);
});

serverSocket.on('getpostkey',function(postkey){
  console.log('getpostkey',postkey);
});
serverSocket.on('chat_result',function(chat_result){
  console.log('chat_result',chat_result);
});
// connected
// authorized {port: "2806", addr: "omsg103.live.nicovideo.jp", thread: "1450455950", user_id: "143728", premium: "1"...}
// getplayerstatus {port: "2806", addr: "omsg103.live.nicovideo.jp", thread: "1450455950", user_id: "143728", premium: "1"...}
// thread {resultcode: "0", thread: "1450455950", last_res: 1863, ticket: "0x14facd80", revision: "1"...}
// chat {thread: "1450455950", vpos: "1276900", date: "1436653369", date_usec: "133900", user_id: "900000000"...}
// chat {thread: "1450455950", vpos: "1299400", date: "1436653594", date_usec: "286322", user_id: "900000000"...}
// chat {thread: "1450455950", vpos: "1299400", date: "1436653594", date_usec: "343074", user_id: "900000000"...}
// chat {thread: "1450455950", vpos: "1299400", date: "1436653594", date_usec: "398244", user_id: "900000000"...}
// chat {thread: "1450455950", vpos: "1299400", date: "1436653594", date_usec: "452674", user_id: "900000000"...}
// getpostkey .1436653726.KL6uM4PMV8cKULkBJqXjdmm1Ye0
// chat {thread: "1450455950", no: "1864", date: "1436653696", date_usec: "110007", mail: "184"...}
// chat_result {text:"てすてすてす", status: "0", thread: "1450455950", no: "1864", date: "1436653696", date_usec: "110007", mail: "184"...}
</script>
```

### userSessionについて <a id="userSession"></a>

userSessionは、ニコニコ生放送内で、以下をアドレスバーに実行すると取得できます。

```js
javascript:alert(document.cookie.split(/;\s*/).reduce(function(other,cookie){if(cookie.match(/^user_session=/)){return cookie.split('=')[1];}else{return other;}},''));
// window.alert:"user_session_000000_0000000000000000000000000000000000000000000000000000000000000000"
```

以下は開発コンソールで取得する場合です。

```js
document.cookie.split(/;\s*/).reduce(function(other,cookie){if(cookie.match(/^user_session=/)){return cookie.split('=')[1];}else{return other;}},'');
// user_session_000000_0000000000000000000000000000000000000000000000000000000000000000
```

### serverSocketEvent:`connect`

起動したサーバーと接続に成功したとき、受信します。サーバーが再起動した時や、クライアントの回線異常により再接続した場合、２回以上イベントが発行することに注意してください。

```js
var serverSocket= io.connect();
serverSocket.on('connect',function(){
  console.log('connected');
});
// connected
```

### serverSocketEvent:`authorized`

サーバーの`auth`イベントへuserSessionを送信し、認証に成功したとき、受信します。

```js
var serverSocket= io.connect();
serverSocket.on('connect',function(){
  console.log('connected');

  serverSocket.emit('auth',userSession);
});
serverSocket.on('authorized',function(debugPlayerStatus){
  console.log('authorized',debugPlayerStatus);
});
// connected
// authorized {port: "2806", addr: "omsg103.live.nicovideo.jp", thread: "1450455950", user_id: "143728", premium: "1"...}
```

### serverSocketEvent:`thread`

サーバーの`view`イベントへチャンネルidを送信し、スレッドに接続できたとき、受信します。

```js
var userSession= 'user_session_000000_0000000000000000000000000000000000000000000000000000000000000000';

var serverSocket= io.connect();
serverSocket.on('connect',function(){
  console.log('connected');

  serverSocket.emit('auth',userSession);
});
serverSocket.on('authorized',function(debugPlayerStatus){
  console.log('authorized',debugPlayerStatus);

  serverSocket.emit('view','nsen/hotaru');
});
serverSocket.on('thread',function(thread){
  console.log('thread',thread);
});
serverSocket.on('chat',function(chat){
  console.log('chat',chat);
});
// connected
// authorized {port: "2806", addr: "omsg103.live.nicovideo.jp", thread: "1450455950", user_id: "143728", premium: "1"...}
// thread {resultcode: "0", thread: "1450455950", last_res: 1863, ticket: "0x14facd80", revision: "1"...}
```

### serverSocketEvent:`chat`

チャンネルidのコメント１件につき１イベントを受信します。

```js
var userSession= 'user_session_000000_0000000000000000000000000000000000000000000000000000000000000000';

var serverSocket= io.connect();
serverSocket.on('connect',function(){
  console.log('connected');

  serverSocket.emit('auth',userSession);
});
serverSocket.on('authorized',function(debugPlayerStatus){
  console.log('authorized',debugPlayerStatus);

  serverSocket.emit('view','nsen/hotaru');
});
serverSocket.on('thread',function(thread){
  console.log('thread',thread);
});
serverSocket.on('chat',function(chat){
  console.log('chat',chat);
});
// connected
// authorized {port: "2806", addr: "omsg103.live.nicovideo.jp", thread: "1450455950", user_id: "143728", premium: "1"...}
// thread {resultcode: "0", thread: "1450455950", last_res: 1863, ticket: "0x14facd80", revision: "1"...}
// chat {thread: "1450455950", vpos: "1276900", date: "1436653369", date_usec: "133900", user_id: "900000000"...}
// chat {thread: "1450455950", vpos: "1299400", date: "1436653594", date_usec: "286322", user_id: "900000000"...}
// chat {thread: "1450455950", vpos: "1299400", date: "1436653594", date_usec: "343074", user_id: "900000000"...}
// chat {thread: "1450455950", vpos: "1299400", date: "1436653594", date_usec: "398244", user_id: "900000000"...}
// chat {thread: "1450455950", vpos: "1299400", date: "1436653594", date_usec: "452674", user_id: "900000000"...}
```

### serverSocketEvent:`chat_result`

サーバーの`comment`イベントへ文章を送信し、結果が返ったとき、受信します。
コールバックの第一引数には、成否の情報statusを含んでいます。

```js
//...
serverSocket.on('thread',function(thread){
  console.log('thread',thread);

  serverSocket.emit('comment','てすてすてす');
});
serverSocket.on('chat_result',function(chat_result){
  console.log('chat_result',chat_result);
});
// chat_result {text:"てすてすてす", status: "0", thread: "1450455950", no: "1864", date: "1436653696", date_usec: "110007", mail: "184"...}
```

### serverSocketEvent:`getplayerstatus`

このイベントはデバッグ用です。自身の`thread`イベントの直前に受信します。コールバックの第一引数には、サーバーが使用した接続に必要な最低限な情報と、getplayerstatusのパース前のxmlデータを含んでいます。

```js
serverSocket.on('getplayerstatus',function(playerStatus){
  console.log('getplayerstatus',playerStatus);
});
// getplayerstatus {addr: "omsg103.live.nicovideo.jp"port: "2806"premium: "1"thread: "1450455950"user_id: "143728"xml: "<?xml version="1.0" encoding="utf-8"?>↵<getplayerstatus status="ok" time="1436653695"><stream><id>lv227714286</id><title>Nsen - 蛍の光チャンネル</title><description>Nsenからの去り際に自主的にお立ち寄り下さい。Nsenをご堪能頂いた後、また、ネットサーフィンを終え眠りにつく時などにオススメです。</description>...</getplayerstatus>"}
```

### serverSocketEvent:`getpostkey`

このイベントはデバッグ用です。自身の`chat_result`イベントの直前に受信します。コールバックの第一引数には、tcpサーバーへの書き込みに必要なpostkeyのみが渡されます。

```js
serverSocket.on('getpostkey',function(postkey){
  console.log('getpostkey',postkey);
});
// getpostkey .1436653726.KL6uM4PMV8cKULkBJqXjdmm1Ye0
```

### serverSocketEvent:`warn`

このイベントはデバッグ用です。サーバーが補足したエラーを受け取ります。

```js
serverSocket.emit('auth','anonymous coward');
serverSocket.emit('view','nothing far');
serverSocket.emit('comment','Im invalid user');

serverSocket.on('warn',function(error){
  console.log(error);
});
// notlogin
// notfound
// nothread
```

## serverSocket.emit('nickname',user_id,callback) -> {error,nickname}

[静画API](http://seiga.nicovideo.jp/api/user/info?id=143728)へアクセスしてユーザー名をコールバック関数に渡します。ユーザーが存在しない場合でも、nicknameが`-`のユーザーとして扱うことに注意してください。

```js
serverSocket.emit('nickname',143728,function(error,nickname){
  console.log(nickname);// 59naga
});

serverSocket.emit('nickname',9999999999,function(error,nickname){
  console.log(nickname);// -
});

serverSocket.emit('nickname','invalid',function(error,nickname){
  console.log(error);// idは数字を入力してください
  console.log(nickname);// undefined
});
```

### serverSocketEvent:`end_of_thread`

問い合わせたチャンネルidが終了した／終了している場合、このイベントを受信します。後述の`current`イベントをサーバーに送信することで、次枠が開始していないか確認できます。

## serverSocket.emit('current') -> playerStatus

`view`イベントで問い合わせた配信のコミュニティidの現在配信中の配信情報を取得します。これは、`end_of_thread`イベントを受け取ってしばらく後、次枠が同じコミュニティで配信された時、検出できることを意味します。

# Test

```bash
$ git clone https://github.com/59naga/nicolive.io.git
$ cd nicolive.io
$ npm install

$ export SESSION=your_user_session_value
$ npm test
```

License
---
[MIT][License]

[License]: http://59naga.mit-license.org/

[sauce-image]: http://soysauce.berabou.me/u/59798/nicolive.io.svg
[sauce]: https://saucelabs.com/u/59798
[npm-image]:https://img.shields.io/npm/v/nicolive.io.svg?style=flat-square
[npm]: https://npmjs.org/package/nicolive.io
[travis-image]: http://img.shields.io/travis/59naga/nicolive.io.svg?style=flat-square
[travis]: https://travis-ci.org/59naga/nicolive.io
[coveralls-image]: http://img.shields.io/coveralls/59naga/nicolive.io.svg?style=flat-square
[coveralls]: https://coveralls.io/r/59naga/nicolive.io?branch=master
