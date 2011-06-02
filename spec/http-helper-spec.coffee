{puts,inspect} = require 'sys'
joinPath = require('path').join
assert = require 'assert'
vows = require 'vows'

vh = require '../src/http-helper'

testPort = 50666
requestFromTestServer = vh.buildRequest "localhost:#{testPort}"

requestWithUpload = requestFromTestServer.with
  headers: {'Content-Type': 'image/jpeg'}
  bodyFromFile: "./fixtures/awesome-cat-jacket.jpg"

vows.describe('Vows HTTP macros')
  
  .addBatch
    'start test server':
      topic: -> testServer.listen testPort, @callback
      'should have started': -> null

  .addBatch
    'GET  /': requestFromTestServer.shouldRespond 200
      'should say something': (res) -> assert.isTrue res.body.length > 0
    
    'POST /': requestFromTestServer.shouldRespond 202
    
    'PUT  /upload': requestWithUpload.shouldRespond 201
      'should have byte count': (res) -> assert.include res.body, '278055'
    
    'POST /upload': requestFromTestServer    
      .with
        headers: {'Content-Type': "multipart/form-data; boundary=||BOUNDARY||"}
        bodyFromFile: "./fixtures/multipart-form-upload"
    
      .shouldRespond 200
        'should have antagonist': (res) -> assert.include res.json.antagonist, 'whale'
    
    'GET  /creds': requestFromTestServer
      .with
        credentials:
          username: 'foo@bar.com'
          password: 'baz:quux'
    
      .shouldRespond 200
        'should have credentials': (res) ->
          assert.equal res.json.username, 'foo@bar.com'
          assert.equal res.json.password, 'baz:quux'
    
    'GET  /redirect': requestFromTestServer.shouldRespond 302
    
    'GET  /echo': vh.buildRequest(
      "localhost:#{testPort}"
      json: {a: 5, b: false}
    ).with(-> headers: {"x-foo": 'bar'})
      .shouldRespond 200
        'should have headers and JSON body': (res) ->
          obj = JSON.parse res.body
          assert.equal obj.a, 5
          assert.isFalse obj.b
  
  .addBatch
    'stop test server':
      topic: -> testServer.close(); return true
      'should have stopped': -> null

  .export module

testServer = require('http').createServer (request, response) ->
  respond = (code, bodyTextOrRedirectLocation) ->
    if Math.floor(code / 100) is 3
      response.writeHead code,
        'Content-Type': 'text/plain'
        'Location': bodyTextOrRedirectLocation 
      response.end ''
    else
      response.writeHead code, 'Content-Type': 'text/plain'
      response.end bodyTextOrRedirectLocation
      
  countRequestBodyBytes = (cb) ->
    count = 0
    request.setEncoding 'binary'
    request.on 'data', (data) -> count += data.length
    request.on 'end', -> cb null, count
    
  handleCredsRoute = ->
    if (authHeader = request.headers['authorization'])?
      b64Val = authHeader.replace 'Basic ', ''
      [user,pass...] = new Buffer(b64Val, 'base64').toString().split ':'
      respond 200, JSON.stringify username: user, password: pass.join ':'
    else respond 401, "You didn't provide credentials"
    
  handleMultipartRoute = ->
    form = new (require('formidable').IncomingForm)
    form.parse request, (err, fields, files) ->
      if err?
        puts inspect err
        respond 500, err.toString()
      else respond 200, JSON.stringify {fields, files}
  
  gatherBodyText = (cb) ->
    text = ''
    request.setEncoding 'utf8'
    request.on 'data', (data) -> text += data
    request.on 'end', -> cb null, text

  switch request.method
    when 'GET'
      switch request.url
        when '/redirect' then respond 302, 'http://www.google.com/'
        when '/creds' then handleCredsRoute()
        when '/echo' then gatherBodyText (err, text) ->
          if err? then respond 500, err.toString()
          else respond 200, text
        else respond 200, 'Howdy'
    when 'POST'
      if request.url.indexOf('/upload') > -1 then handleMultipartRoute()
      else respond 202, 'Will do'
    when 'PUT'  then countRequestBodyBytes (err, count) ->
      if err? then respond 500, err.toString()
      else respond 201, "Sweet. You uploaded #{count} bytes"
