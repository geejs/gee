ES = require('event-stream')
Path = require('path')
Parse = require("./parse")
Utils = require("./utils")
_ = require("lodash")
log = require("./logger").getLogger("ifcond")

###
# coffee: { bare: true, other: asfasdf, $when: "path.extname == '.coffee'" }
#
# ifcond(stream: coffee, options: options, cond: " == ")
###
module.exports = (options) ->

  modifyFile = (file) ->
    file.extname = Path.extname(file.path)
    condition = options.cond?.$when

    if condition
      truthy = Parse.evalExpression(condition, file)

    if truthy
      stream = options.stream.apply(null, [options.options] || [])
      stream.pipe this
      # is there a more efficient way to do this
      return stream.write(file)

    # passthrough
    return this.emit('data', file)

  return ES.through(modifyFile)

