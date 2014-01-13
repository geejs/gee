ES = require('event-stream')
baseStream = require('stream')
log = require("./logger").getLogger('tap')

id = 1
cache = {}

utils = (tapStream, file) ->
  through: (filter, args) ->
    if filter.__tapId
      stream = cache[filter.__tapId]
      cache[filter.__tapId] = null unless stream

    unless stream
      if log.DEBUG
        if !Array.isArray(args)
          throw new Error("Args must be an array to `apply` to the filter")
      stream = filter.apply(null, args)
      filter.__tapId = ""+id
      cache[filter.__tapId] = stream
      id += 1
      stream.pipe tapStream
    stream.write file
    stream


###
# Taps into the pipeline and allows user to easily re-route or change
# content.
###
module.exports = (lambda) ->
  modifyFile = (file) ->
    obj = lambda(file, utils(this, file))

    # passthrough if user returned a stream
    this.emit('data', file) unless obj instanceof baseStream

  return ES.through(modifyFile)

