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

throw new Error 'process.env.SESSION is undefined' unless userSession

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

    client.on 'getplayerstatus',(playerStatus)->
      {port,addr,thread}= playerStatus
      expect(port).toBeGreaterThan 200
      expect(addr).toMatch /.live.nicovideo.jp$/
      expect(thread).toBeGreaterThan 1000000000

      {id,title,picture_url,default_community}= playerStatus
      expect(id).toMatch /^lv/
      expect(title).toBe 'Nsen - 蛍の光チャンネル'
      expect(picture_url).toMatch 'http://nl.simg.jp/img/a35/103321.39a510.jpg'
      expect(default_community).toBe ''

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

  describe 'Found current live',->
    it 'old to current',(done)->
      client.emit 'view','lv227889668'
      client.once 'end_of_thread',(chat)->
        client.emit 'current',(error,playerStatus)->
          expect(error).toBe null

          {port,addr,thread}= playerStatus
          expect(port).toBeGreaterThan 200
          expect(addr).toMatch /.live.nicovideo.jp$/
          expect(thread).toBeGreaterThan 1000000000

          {id,title,picture_url,default_community}= playerStatus
          expect(id).toMatch /^lv/
          expect(title).toMatch 'ブラウザベースのコメントビューアつくってる'
          expect(picture_url).toMatch 'http://icon.nimg.jp/community/218/co2183236.jpg'
          expect(default_community).toBe 'co2183236'

          done()

  xdescribe 'TODO: heartbeat'

  describe 'Error handling',->
    it 'invalid auth',(done)->
      client.emit 'auth','そんなセッションない'
      client.once 'warn',(error)->
        expect(error).toBe 'notlogin'
        done()

    it 'invalid view',(done)->
      client.emit 'view','そんなサーバーない'
      client.once 'warn',(error)->
        expect(error).toBe 'notfound'
        done()

    it 'invalid comment',(done)->
      client.emit 'comment','ログインできてない'
      client.once 'warn',(error)->
        expect(error).toBe 'nothread'
        done()
       
  describe 'fetch nickname',->
    it 'fetch nickname',(done)->
      client.emit 'nickname',143728,(error,nickname)->
        expect(error).toBe null
        expect(nickname).toBe '59'
        done()

    it 'invalid id',(done)->
      client.emit 'nickname','fdafdsa',(error,nickname)->
        expect(error).toBe 'idは数字を入力してください'
        expect(nickname).toBeUndefined()
        done()
