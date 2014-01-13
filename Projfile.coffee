Promise = require("bluebird")
Path = require("path")
coffee = require("gulp-coffee")
dest = require("gulp").dest
less = require("gulp-less")
uglify = require("gulp-uglify")
Fs = require("fs")
$ = require("gee-shell")



exports.project = (gee) ->
  {argv, tap} = gee

  default: "clean"

  "default@release": "clean scripts"

  clean: ->
    $.rm '-rf', 'dist'

  scripts:
    src:  'src/**/*.{coffee,js}'
    pipeline: -> [
      tap (file, t) ->
        t.through(coffee, []) if Path.extname(file.path) == '.coffee'
      dest 'dist'
    ]
