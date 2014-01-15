ES = require('event-stream')

###
# Taps into the pipeline and allows user to easily change file
# contents or path using strings.
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

