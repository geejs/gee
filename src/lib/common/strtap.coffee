ES = require('event-stream')
baseStream = require('stream')
DEBUG = process.env.NODE_ENV is 'development'
Promise = require('bluebird')


###
# Taps into the pipeline and allows user to easily route data through
# another stream or change content.
###
module.exports = (lambda) ->

  modifyFile = (file) ->
    that = @

    asset = {path: file.path, contents: file.contents.toString()}

    cb = (err, update) ->
      throw new Error(err) if err

      if update
        file.path = asset.path
        file.contents = new Buffer(asset.contents)

      # passthrough
      that.emit('data', file)

    if lambda.length == 2
      lambda asset, cb
    else
      cb null, lambda(asset)

  return ES.through(modifyFile)

