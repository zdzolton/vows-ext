{puts,inspect} = require 'sys'
joinPath = require('path').join
assert = require 'assert'
vows = require 'vows'

vh = require '../http-helper'

testPort = 50666

basicRequest = vh.buildRequest "localhost:#{testPort}"

requestUploadPhoto = vh.buildRequest "localhost:#{testPort}",
  headers: {'Content-Type': 'image/jpeg'}
  bodyFromFile: "./fixtures/awesome-cat-jacket.jpg"

mimeBoundary = '||BOUNDARY||'

requestUploadMultipart = vh.buildRequest "localhost:#{testPort}",
  headers: {'Content-Type': "multipart/form-data; boundary=#{mimeBoundary}"}
  body: [
    "--#{mimeBoundary}"
    'Content-Disposition: form-data; name="foo"'
    ''
    'forty-two'

    "--#{mimeBoundary}"
    'Content-Disposition: form-data; name="bar"; filename="my-novel.txt"'
    'Content-Type: text/plain'
    ''
    'Call me Ishmael. Some years ago--never mind how long precisely--'
    'having little or no money in my purse, and nothing particular to '
    'interest me on shore, I thought I would sail about a little and '
    'see the watery part of the world. It is a way I have of driving '
    'off the spleen and regulating the circulation. Whenever I find '
    'myself growing grim about the mouth; whenever it is a damp, '
    'drizzly November in my soul; whenever I find myself involuntarily '
    'pausing before coffin warehouses, and bringing up the rear of '
    'every funeral I meet; and especially whenever my hypos get such an '
    'upper hand of me, that it requires a strong moral principle to '
    'prevent me from deliberately stepping into the street, and '
    'methodically knocking people\'s hats off--then, I account it high '
    'time to get to sea as soon as I can. This is my substitute for '
    'pistol and ball. With a philosophical flourish Cato throws himself '
    'upon his sword; I quietly take to the ship. There is nothing '
    'surprising in this. If they but knew it, almost all men in their '
    'degree, some time or other, cherish very nearly the same feelings '
    'towards the ocean with me.'

    "--#{mimeBoundary}--"
    ''
  ].join '\r\n'

vows.describe('Vows HTTP macros')
  
  .addBatch
    'start test server':
      topic: -> testServer.listen testPort, @callback
      'should have started': -> null

  .addBatch
    'GET  /': basicRequest.respondsWith 200
      'should say something': (res) -> assert.isTrue res.body.length > 0
    
    'POST /': basicRequest.respondsWith 202

    'PUT  /upload': requestUploadPhoto.respondsWith 201
      'should have byte count': (res) -> assert.include res.body, '278055'
    
    'POST /upload': requestUploadMultipart.respondsWith 200

  .addBatch
    'stop test server':
      topic: -> testServer.close(); return true
      'should have stopped': -> null

  .export module

testServer = require('http').createServer (request, response) ->
  respond = (code, bodyText) ->
    response.writeHead code, 'Content-Type': 'text/plain'
    response.end bodyText
  countRequestBodyBytes = (cb) ->
    count = 0
    request.setEncoding 'binary'
    request.on 'data', (data) -> count += data.length
    request.on 'end', -> cb null, count
  switch request.method
    when 'GET'  then respond 200, 'Howdy'
    when 'POST'
      if -1 == request.url.indexOf '/upload' then respond 202, 'Will do'
      else 
        form = new (require('formidable').IncomingForm)
        form.parse request, (err, fields, files) ->
          if err?
            puts inspect err
            respond 500, err.toString()
          else respond 200, JSON.stringify [fields, files]
    when 'PUT'  then countRequestBodyBytes (err, count) ->
      if err? then respond 500, err.toString()
      else respond 201, "Sweet. You uploaded #{count} bytes"
