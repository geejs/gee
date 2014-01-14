Path = require("path")
Promise = require("bluebird")
coffee = require("gulp-coffee")
dest = require("gulp").dest
uglify = require("gulp-uglify")
$ = require("gee-shell")

exports.project = (gee) ->
  {argv, tap, strtap} = gee

  # tap into string data easily, return true to update
  addHeader = ->
    strtap (asset) ->
      header = "/*** YOUR HEADER */"
      asset.contents = header + '\n' + asset.contents
      true

  # process coffee files only if file has extension .coffee
  cafe = ->
    tap (file, t) ->
      t.through(coffee, []) if Path.extname(file.path) == '.coffee'

  default: "clean async asyncPromise scripts"

  clean: ->
    $.rm '-rf', 'dist'

  scripts:
    src:  'src/**/*.{coffee,js}'
    pipe: -> [cafe(), dest('build')]

    release: -> [cafe(), uglify(), addHeader(), dest('dist')]

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

