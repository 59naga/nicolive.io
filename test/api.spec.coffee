# Dependencies
nicoliveIo= require '../src'
socketIoClient= require 'socket.io-client'

NicoliveIo= (require '../src').NicoliveIo
express= require 'express'
Promise= require 'bluebird'
request= Promise.promisify(require 'request')

# Environment
port= 59798
userSession= process.env.SESSION

# Specs
describe 'NicoliveIo using Express4',->
  io= null
  beforeEach (done)->
    app= express()
    app.get '/',(req,res)->
      res.end 'foo'

    io= new NicoliveIo app
    io.listen port,done

  afterEach (done)->
    io.close done

  it 'GET /',(done)->
    request 'http://localhost:'+port
    .spread (response,body)->
      expect(body).toBe 'foo'

      done()

  it 'GET /socket.io/socket.io.js',(done)->
    request 'http://localhost:'+port+'/socket.io/socket.io.js'
    .spread (response)->
      expect(response.headers['content-type']).toBe 'application/javascript'

      done()

describe 'nicoliveIo',->
  client= null
  beforeEach (done)->
    nicoliveIo.listen port,->
      client= socketIoClient 'http://localhost:'+port,
        port: port
        forceNew: true
        reconnect: false

      client.emit 'auth',userSession
      client.on 'authorized',done

  afterEach (done)->
    client.disconnect()
    nicoliveIo.close done

  it 'view at nsen/hotaru',(done)->
    client.emit 'view','nsen/hotaru'
    client.on 'getplayerstatus',(playerStatus)->
      {port,addr,thread}= playerStatus
      expect(port).toBeTruthy()
      expect(addr).toBeTruthy()
      expect(thread).toBeTruthy()

    last_res= null
    client.on 'thread',(thread)->
      expect(thread.resultcode).toBe '0'
      expect(thread.revision).toBe '1'

      i= 0
      last_res= thread.last_res
      client.on 'chat',(chat)->
        expect(++last_res).toBe chat.no
        i++

        done() if i is 5

  it 'anonymous comment at nsen/hotaru',(done)->
    comment= Date.now()+' via '
    comment+= if process.env.TRAVIS then 'TravisCI' else 'NicoliveIo'

    client.emit 'view','nsen/hotaru'
    client.on 'getplayerstatus',(playerStatus)->
      {port,addr,thread}= playerStatus
      expect(port).toBeTruthy()
      expect(addr).toBeTruthy()
      expect(thread).toBeTruthy()

    client.on 'thread',(thread)->
      expect(thread.resultcode).toBe '0'
      expect(thread.revision).toBe '1'

      client.emit 'comment',comment
      client.on 'getpostkey',(postkey)->
        expect(postkey).toBeTruthy()

      client.once 'chat_result',(chat_result)->
        expect(chat_result.status).toBe '0'
        expect(chat_result.description).toBe '受理されました'
        expect(chat_result.text).toBe comment

        done()
