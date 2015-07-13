# Dependencies
Thread= (require './thread').Thread

Socketio= require 'socket.io'
Server= (require 'http').Server

util= require 'util'
querystring= require 'querystring'

Promise= require 'bluebird'
request= Promise.promisify(require 'request')
cheerio= require 'cheerio'

# Private
status= require './status'
api=
  getPlayerStatus: 'http://live.nicovideo.jp/api/getplayerstatus/%s'
  getPostKey: 'http://live.nicovideo.jp/api/getpostkey'
  heartbeat: 'http://live.nicovideo.jp/api/heartbeat?v='
  fetchNickname: 'http://seiga.nicovideo.jp/api/user/info'

# Public
class NicoliveIo extends Socketio
  constructor: (requestListener)->
    @server=
      if requestListener
        new Server requestListener
      else
        new Server (req,res)->
          res.writeHead 200,{'Content-Type':'text/html'}
          res.end '''
            <head><script src="/socket.io/socket.io.js"></script></head>
            <body><h1>Welcome to Underground...</h1></body>
          '''
    super @server

    @on 'connection',(client)=>
      client.on 'auth',(userSession)=>
        @getPlayerStatus 'nsen/hotaru',userSession
        .then (playerStatus)->
          client.emit 'authorized',playerStatus
          client.userSession= userSession
        .catch (error)->
          client.emit 'error',error

      client.on 'view',(nicoliveId,options={})=>
        client.thread.destroy() if client.thread?

        @getPlayerStatus nicoliveId,client.userSession
        .then (playerStatus)->
          client.playerStatus= playerStatus

          client.emit 'getplayerstatus',playerStatus
          client.thread= new Thread client,playerStatus,options
        .catch (error)->
          client.emit 'error',error
          
      client.on 'comment',(comment,attributes={})=>
        unless client.thread?.attributes
          client.emit 'warn','nothread'
          return client.emit 'chat_result',{status:'-1',description:status['-1'].description}

        @getPostKey client.thread.attributes,client.userSession
        .then (postkey)->
          client.emit 'getpostkey',postkey
          attributes.postkey= postkey
          attributes.mail?= 184
          client.thread?.comment comment,attributes
        .catch (error)->
          client.emit 'error',error

      client.on 'nickname',(userId,callback)=>
        @fetchNickname userId
        .then (nickname)->
          callback null,nickname
        .catch (error)->
          callback error

      client.on 'error',(error)->
        client.emit 'warn',error

      client.on 'current',=>
        communityId= client.playerStatus.default_community

        @getPlayerStatus communityId,client.userSession
        .then (playerStatus)->
          client.emit 'current',playerStatus
        .catch (error)->
          client.emit 'current',error
      
      client.on 'disconnect',->
        client.thread.destroy() if client.thread?
        delete client.thread

  getPlayerStatus: (nicoliveId,userSession)->
    url= util.format api.getPlayerStatus,nicoliveId

    request
      url: url
      headers:
        Cookie: 'user_session='+userSession
    .spread (response,xml)->
      $= cheerio.load xml,{xmlMode:yes}
      error= $('getplayerstatus error code').text()

      return Promise.reject error if error

      port= $('getplayerstatus ms port').eq(0).text()
      addr= $('getplayerstatus ms addr').eq(0).text()
      thread= $('getplayerstatus ms thread').eq(0).text()

      user_id= $('user_id').eq(0).text()
      premium= $('is_premium').eq(0).text()

      id= $('id').eq(0).text()
      title= $('title').eq(0).text()
      picture_url= $('picture_url').eq(0).text()
      default_community= $('default_community').eq(0).text()

      {
        port,addr,thread
        user_id,premium
        id,title,picture_url,default_community
        xml
      }

  getPostKey: ({thread,last_res},userSession)->
    block_no= Math.round ((last_res+1)/100)
    url= api.getPostKey+'?'+(querystring.stringify {thread,block_no})

    request
      url: url
      headers:
        Cookie: 'user_session='+userSession
    .spread (response,postkeyBody)->
      [...,postkey]= postkeyBody.split '='

      postkey

  heartbeat: (nicoliveId)->
    url= api.heartbeat+'?v='+nicoliveId

    request
      url: url
      headers:
        Cookie: 'user_session='+userSession
    .spread (response,body)->

      body

  fetchNickname: (userId)->
    url= api.fetchNickname+'?id='+userId

    request url
    .spread (response,xml)->
      $= cheerio.load xml,{xmlMode:yes}
      error= $('errors error').text()

      return Promise.reject error if error

      $('nickname').text()

  listen: ()->
    @server.listen arguments...

  close: ->
    @server.close arguments...

module.exports= new NicoliveIo
module.exports.NicoliveIo= NicoliveIo
