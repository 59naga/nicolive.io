# Dependencies
cheerio= require 'cheerio'

Socket= (require 'net').Socket

# Private
status= require './status'
resultcode= require './resultcode'

# Public
class Thread extends Socket
  constructor: (client,@playerStatus,options={})->
    super()

    {port,addr,thread}= @playerStatus

    @connect port,addr
    @on 'connect',=>
      options.res_from?= 5

      $= cheerio.load '<thread/>',{xmlMode:yes}
      $thread= $ 'thread'
      $thread.attr
        thread: thread
        version: '20061206'
        res_from: '-'+options.res_from
      @write $.html()+'\0'

      @setEncoding 'utf-8'

    chunks= ''
    @on 'data',(chunk)=>
      chunks+= chunk
      return unless chunk[chunk.length-1] is '\0'

      $= cheerio.load chunks,{xmlMode:yes}
      chunks= null

      unless @attributes
        $thread= $ 'thread'

        @attributes= $thread.attr()
        @attributes.description= resultcode[@attributes.resultcode]?.description
        @attributes.last_res= parseInt @attributes.last_res
        client.emit 'thread',@attributes

      for chat in $ 'chat'
        $chat= $ chat

        data= $chat.attr()
        data.no?= ++@attributes.last_res
        data.text= $chat.text()

        client.emit 'chat',data

      for chat_result in $ 'chat_result'
        $chat_result= $ chat_result

        data= $chat_result.next().attr() or {}
        data.status= $chat_result.attr 'status'
        data.description= status[data.status]?.description
        data.text= $chat_result.next().text()

        client.emit 'chat_result',data

  comment: (comment,attributes)->
    {thread,ticket}= @attributes
    {user_id,premium}= @playerStatus

    $= cheerio.load '<chat/>',{xmlMode:yes}
    $chat= $ 'chat'
    $chat.attr {thread,ticket,user_id,premium}
    $chat.attr attributes
    $chat.text comment.toString()
    data= $.html()+'\0'

    if process.env.TRAVIS
      console.log 'fold:start:comment'
      console.log data
      console.log 'fold:env:comment'

    @write data

module.exports.Thread= Thread
