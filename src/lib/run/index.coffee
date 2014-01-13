Fs = require("fs")
Path = require("path")
log = require("../common/logger").getLogger("run")
Str = require("underscore.string")
Server = require("../serve/server")
Promise = require("bluebird")
Project = require("./project")
_ = require("lodash")


###
# Loads the project method in the Projfile.
#
# The tasks to execute is performed by `options.executeTask`.
#
# @param {Object} options = {
#   {Object} program Program options.
#   {String} projfilePath The path to Projfile
#   {Function} executeTasks The execute lambda.
# }
###
loadProject = (options) ->
  throw new Error("Options.argv is required") unless options.argv
  throw new Error("Options.projfilePath is required") unless options.projfilePath
  Project.load(options.projfilePath, options.argv)


###
# Runs task
###
exports.run = (options) ->
  {argv, tasks} = options
  _project = null
  startTime = Date.now()

  Promise
    .try(loadProject, [options])

    .then (project) ->
      _project = project

      if tasks.length == 0
        if project.tasks.default
          tasks = ["default"]
        else
          return Promise.reject("usage")

      # Run the tasks
      project.executeTasks tasks

    .then ->
      serve = argv.serve
      watch = argv.watch

      serverConfig = _project.server
      if serve or watch

        if serve
          dirname = serve
          if dirname.length > 0
            serveOptions = {dirname}
          else if serverConfig
            serveOptions = serverConfig
          else
            serveOptions = dirname: "."

          Server.run serveOptions

        if watch
          _project.watchTasks()

      else
        endTime = Date.now()
        elapsed = endTime - startTime

        log.info("OK #{elapsed/1000} seconds") unless argv.watch


###
# Returns task name and description from project.
###
exports.taskDescriptions = (options) ->
  Promise
    .try(loadProject, [options])
    .then (project) ->
      desc = {}
      for name, task of project.tasks
        continue if name.indexOf("_") == 0  # underscore tasks are private by convention
        desc[name] = task.description
        # should only be extended help
        # if _.isString(task.options)
        #   desc[name].options = task.options
      desc

