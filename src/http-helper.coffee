{puts,inspect} = require 'sys'
request = require 'request'
assert = require 'assert'
{exec} = require 'child_process'
{readFile} =  require 'fs'

exports.buildRequest = (host, opts={}) -> new Request host, opts

jsonTryParse = (json, val) ->
  try JSON.parse json catch e 
    val or null

deepCopy = (obj) ->
  if obj is null then null
  else if Array.isArray obj
    deepCopy el for el in obj
  else if typeof obj is 'object'
    out = {}
    out[name] = deepCopy val for name, val of obj
    out
  else obj

class Request
  constructor: (@host, opts) -> @opts = deepCopy opts

  shouldRespond: (statusCode, additionalVows={}) ->
    context = topic: makeTopicFun @host, @opts
    for name, fun of additionalVows
      context[name] = fun
    context["should respond with a #{statusCode}"] = (res) ->
      assert.equal res.statusCode, statusCode
    return context
  
  with: (moreOpts) ->
    newReqOpts = deepCopy @opts
    for name, val of moreOpts
      newReqOpts[name] = val
    new Request @host, newReqOpts
  
makeTopicFun = (host, opts) ->
  (obj) ->
    [method, path] = @context.name.split /\s+/
    path = replacePathVariables path, obj if obj?
    url = "http://#{host}#{path}"
    reqFun = makeRequest method, url, opts, @callback

makeAuthVal = (creds) ->
  encoded = new Buffer("#{creds.username}:#{creds.password}").toString 'base64'
  "Basic #{encoded}"

replacePathVariables = (path, obj) ->
  path.replace /:([a-z_]+)/gi, (_, name) ->
    val = obj[name]
    if typeof val is 'function' then val.apply obj
    else if val? then val
    else ''

makeRequest = (method, url, opts, cb) ->
  {credentials,json,body,headers,bodyFromFile} = opts
  reqOpts =
    method: method.toUpperCase()
    url: url
    headers: {}
    followRedirect: false
  reqOpts.headers['Authorization'] = makeAuthVal credentials if credentials?
  if headers?
    for own name, val of headers
      reqOpts.headers[name] = val
  reqOpts.json = json if json?
  reqOpts.body = body if body?
  if bodyFromFile? then readFile bodyFromFile, (err, data) ->
    if err? then cb err
    else
      reqOpts.body = data
      doRequest reqOpts, cb
  else doRequest reqOpts, cb

doRequest = (opts, cb) ->
  request opts, (err, res, body) ->
    unless err?
      res.body = body
      res.json = jsonTryParse body
    cb err, res
