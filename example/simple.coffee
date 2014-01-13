Path = require("path")
Promise = require("bluebird")
coffee = require("gulp-coffee")
dest = require("gulp").dest
uglify = require("gulp-uglify")

exports.project = (gee) ->
  {$, argv, tap} = gee

  # tap into pipeline easily
  addHeader = ->
    return tap (file) ->
      header = "/*** YOUR HEADER */"
      file.contents = Buffer.concat([
        new Buffer(header)
        file.contents
      ])

  # process coffee files only if file has extension .coffee
  ifCoffee = ->
    return tap (file, t) ->
      t.through(coffee, []) if Path.extname(file.path) == '.coffee'

  default: "clean async asyncPromise scripts"

  clean: ->
    $.rm '-rf', 'dist'

  scripts:
    src:  'src/**/*.{coffee,js}'
    pipeline: -> [ifCoffee(), dest 'build']

    release: -> [ifCoffee(), uglify(), addHeader(), dest('dist')]

  helloArguments: ->
    console.log "Hello #{argv.message}"

  async: (next) ->
    process.nextTick ->
      console.log "async"
      next()

  asyncPromise: ->
    vow = Promise.pending()
    process.nextTick ->
      console.log "promise"
      vow.fulfill()
    vow.promise

