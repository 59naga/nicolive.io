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
            <head>
              <script src="/socket.io/socket.io.js"></script>
            </head>
            <body>
              <h1>Welcome to Underground...</h1>
            </body>
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
          client.emit 'getplayerstatus',playerStatus
          client.thread= new Thread client,playerStatus,options
          
      client.on 'comment',(comment,attributes={})=>
        console.log arguments if process.env.TRAVIS

        unless client.thread?.attributes
          return client.emit 'chat_result',{status:'-1',description:status['-1'].description}

        @getPostKey client.thread.attributes,client.userSession
        .then (postkey)->
          client.emit 'getpostkey',postkey
          attributes.postkey= postkey
          attributes.mail?= 184
          client.thread?.comment comment,attributes

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
      error= $('getPlayerStatus error code').text()

      return Promise.reject error if error

      port= $('getplayerstatus ms port').eq(0).text()
      addr= $('getplayerstatus ms addr').eq(0).text()
      thread= $('getplayerstatus ms thread').eq(0).text()

      user_id= $('user_id').eq(0).text()
      premium= $('is_premium').eq(0).text()
      {port,addr,thread,user_id,premium,xml}

  getPostKey: ({thread,last_res},userSession)->
    block_no= Math.floor (last_res+1)/100
    url= api.getPostKey+'?'+(querystring.stringify {thread,block_no})

    if process.env.TRAVIS
      console.log 'fold:start:getPostkey'
      console.log url

    request
      url: url
      headers:
        Cookie: 'user_session='+userSession
    .spread (response,postkeyBody)->
      [...,postkey]= postkeyBody.split '='

      console.log response if process.env.TRAVIS
      console.log 'fold:end:getPostkey'

      postkey

  listen: ->
    @server.listen arguments...

  close: ->
    @server.close arguments...

module.exports= new NicoliveIo
module.exports.NicoliveIo= NicoliveIo
