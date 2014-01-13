Fs = require("fs")
CSON = require("cson")
Path = require("path")
YAML = require("js-yaml")
_ = require("lodash")
log = require("../common/logger").getLogger("project")
Utils = require("../common/utils")
Task = require("./task")
PColl = require("pcoll")
Promise = require("bluebird")
Str = require("underscore.string")
$ = require("gee-shell")
tap = require("gulp-tap")

FILTERS = "filters"
FUNCTIONS = "functions"
IMPORTS = "imports"

reservedNames = [FILTERS, FUNCTIONS, IMPORTS]


###
# Converts a Projfile JSON into a JavaScript project that can be excecuted by Runner.
#
# @param projfile The parsed projfile object.
####
class Project

  constructor: (@projfile, filename, argv, @ns="") ->
    @isProgram = _.isFunction(@projfile.project)
    @argv = argv
    @filename = filename
    @dirname = Path.dirname(filename)
    @pm =
      $: $
      argv: argv
      tap: tap

    @filters = {}
    @loadFilters()

    @functions = {}
    @loadFunctions() unless @isProgram

    @tasks = {}
    if @isProgram
      tasks = @loadProgram(@projfile)
      @loadTasks tasks
    else
      @loadTasks @projfile
    @imports = {}

    @loadImports()
    @watchList = {}


  loadProgram: ->
    program = @projfile
    tasks = program.project(@pm)


  loadFilters: ->
    return unless @projfile[FILTERS]

    for name, path of @projfile[FILTERS]
      if path.indexOf("#")
        [path, fname] = path.split("#")

      try
        # TODO this needs to require from APP cwd not this library
        pkg = require(path)
        if _.isFunction(pkg)
          @filters[name] = pkg
        else if fname and _.isObject(pkg)
          @filters[name] = pkg[fname].bind(pkg)
        else
          throw new Error("Module not found")
      catch e
        console.error e.stack
        throw new Error("Could not load filter:", path)
    null


  loadFunctions: ->
    functions = @projfile[FUNCTIONS]

    if functions and !_.isObject(functions)
      throw new Error("Expected object for $functions: ", functions)
    else if _.isObject(functions)
      for pkg, path of functions
        path = Path.resolve(Path.dirname(@filename), path)
        @functions[pkg] = require(path)
    null


  loadImports: (imports) ->
    return unless @projfile[IMPORTS]
    for name, path of @projfile[IMPORTS]
      ns = if @ns then @ns + ":" + name else name
      Project = require("./project")
      @imports[name] = Project.load(path, @argv, ns)
    null


  loadTasks: (tasks) ->
    for name, definition of tasks
      # skip reserved names like functions, imports
      continue if reservedNames.indexOf(name) >= 0

      newTasks = Task.create({name, definition, project: @})
      for k, v of newTasks
        @tasks[k] = v
    null


  getTask: (origName, mode=@argv.mode) ->
      hasAtSign = origName.indexOf("@") > -1
      if hasAtSign
        # if a mode is specified by user in the Projfile then all of
        # its dependencies run in that mode regardles of the cli
        # mode option
        forceMode = Str.strRight(origName, "@")

      if mode and !hasAtSign
        name = origName + "@" + mode
      else
        name = origName

      isImported = Str.include(name, ":")
      if isImported
        # first try mode task
        [ns, name] = name.split(":")
        task = @imports[ns].tasks[name]

        # try default task unless the original name had "@"
        if mode and !task and !hasAtSign
          name = Str.strLeft(name, "@")
          task = @imports[ns].tasks[name]
      else
        # try mode task
        task = @tasks[name]

        # try default task unless the original name had "@"
        if mode and !task and !hasAtSign
          name = Str.strLeft(name, "@")
          task = @tasks[name]

      {task, ns, name}


  ###
  # Executes the environment pipeline including their dependecies
  # in one or more tasks.
  #
  # Note, tasks are only run once!
  #
  # @param {Array} taskNames
  # @param {String} forceMode User specified a dependency with mode in projfile.
  ###
  executeTasks: (taskNames, forceMode) ->
    that = @
    watch = @argv.watch

    # run in test, release, etc mode
    mode = forceMode or @argv.mode

    PColl.eachSeries(taskNames, (origName) ->

      {task, ns, name} = that.getTask(origName, mode)

      return Promise.reject("Invalid task: #{origName}") unless task

      # Watch tasks only if they have a command to execute. Some tasks are
      # dependenies only.
      if watch and (task.files?.include?.length > 0 or task.watch?.length > 0 or task.command? or task.pipeline?)
        that.watchList[origName] = true

      return that.imports[ns].executeTasks([name], forceMode) if ns

      startTime = Date.now()
      logStatus = (prefix="")->
        seconds = (Date.now() - startTime)
        task.log.info "#{prefix}#{seconds} ms"

      if task.dependencies.length > 0
        nocmd = if task.command or task.pipeline then "" else " nocmd"
        task.log.info "deps [#{task.dependencies.join(" ")}]#{nocmd} begin"
        task.log.indent()

        that
          .executeTasks(task.dependencies, forceMode)
          .then ->
            task.execute()
          .finally ->
            task.log.unindent()
            logStatus("end ")
      else
        Promise
          .try(task.execute, [], task)
          .then ->
            logStatus()
    )
    .catch (err) ->
      if err
        if err != "PM_SILENT"
          if err.stack
            log.error err.stack
          else
            log.error err
        log.error "FAIL"
      Promise.reject "PM_SILENT"


  ###
  # Start all tasks which were collected when the task and its dependencies
  # ran.
  ###
  watchTasks: ->
    for name of @watchList
      {task, name, ns} = @getTask(name)
      do (task, name) ->
        try
          task.watchFiles()
        catch err
          if err.stack
            task.log.error err.stack
          else
            task.log.error err
          throw new Error("PM_SILENT")
    null


  @load: (args...) ->
    try
      filename = Path.resolve(args[0])
      extname = Path.extname(filename)

      if [".cson .json .yaml"].indexOf(extname) >= 0
        Project.loadJSON args...
      else
        mojule = require(filename)
        if _.isFunction(mojule.project)
          Project.loadModule mojule, args...
        else
          Project.loadJSON args...
    catch e
      console.error e
      throw new Error("Could not load #{args[0]}", e)


  @loadModule: (program, projfilePath, argv, ns="") ->
    filename = Path.resolve(projfilePath)
    new Project(program, filename, argv, ns)

  ###
  # JSON mode is declarative which will is the only format supported by
  # Projmate GUI - Project Editor.
  ###
  @loadFile: (projfilePath, argv, ns="") ->
    filename = Path.resolve(projfilePath)
    source = Fs.readFileSync(filename, "utf8")

    switch Path.extname(filename)
      when ".coffee", ".cson"
        projfile = CSON.parseSync(source)
      when ".js", ".json"
        projfile = JSON.parse(source)
      when ".yaml", ".yml"
        projfile = YAML.safeLoad(source)
      else
        throw new Error("Unknown Projfile extension: #{projfilePath}")

    new Project(projfile, filename, argv, ns)



module.exports = Project
