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

requestUploadMultipart = vh.buildRequest "localhost:#{testPort}",
  headers: {'Content-Type': "multipart/form-data; boundary=||BOUNDARY||"}
  bodyFromFile: "./fixtures/multipart-form-upload"

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
      'should have antagonist': (res) -> assert.include res.json.antagonist, 'whale'

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
          else respond 200, JSON.stringify {fields, files}
    when 'PUT'  then countRequestBodyBytes (err, count) ->
      if err? then respond 500, err.toString()
      else respond 201, "Sweet. You uploaded #{count} bytes"
