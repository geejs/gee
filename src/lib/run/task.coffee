_ = require("lodash")
Chokidar = require("chokidar")
Util = require("util")
minimatch = require("minimatch")
Str = require("underscore.string")
Parse = require("../common/parse")
Logger = require("../common/logger")
Promise = require("bluebird")
Gulp = require("gulp")
ifcond = require("../common/ifcond")
ES = require("event-stream")

FOOID = 0

aliasTaskProps =
  description: ["des", "desc"]
  dependencies: ["dep", "deps"]
  files: ["src"]
  command: ["cmd"]
  pipeline: ["line"]
  options: ["opts"]

class Task

  # Creates an instance of this object.
  #
  # @param options = {
  #   log: logger with name
  #   name:
  #   config:
  # }
  constructor: (@options) ->
    {name, definition, project} = @options

    @name = name
    @project = project
    @mode = project.argv.mode

    # if this task is in @release mode, then try @release mode
    # in all dependencies first
    if name.indexOf('@') > 0
      @mode = Str.strRight('@')

    logName = if project.ns then project.ns + ':' + name else name
    @log = Logger.getLogger(logName)
    @watching = false

    definition = @normalizeDefinition(definition)

    # init attributes
    @__definition = definition
    @command = definition.command
    @pipeline = definition.pipeline
    @description = definition.description
    @dependencies = definition.dependencies
    @files = definition.files
    @options = definition.options
    @watch = []

    # When watching a task with an aggregator all files must be processed.
    # For example, when compiling a CoffeeScript source file, the
    # single file can be processed indepedendently of all other files.
    # However if there is an aggregator, then all coffee files need to
    # loaded for aggregation.
    @rebuild = null
    @changeset = []


  compileFunctionString: (s) ->
    info = Parse.parseFunc(s)
    throw new Error("Invalid function string handler: #{s}") unless info

    {pkg, fn, args} = info
    args ?= []

    packg = @project.functions[pkg]
    throw new Error("Package #{pkg} not found for function: #{s}") unless packg
    handler = packg[fn]
    throw new Error("Function #{fn} not found in package: #{s}") unless handler

    that = @
    log = @log

    return ->
      # may be called multiple times, eg in watch mode
      newargs = _.clone(args)
      for v, i in newargs
        switch v
          when "next"
            vow = Promise.pending()
            newargs[i] = vow.callback
            used = true
          when "argv"
            newargs[i] = that.project.argv
          when "task"
            newargs[i] = that
          when "assets"
            newargs[i] = that.assets

      handler.apply packg, newargs
      return vow.promise if used

  wrapInPromise: (fn) ->
    return ->
      if fn.length is 1
        vow = Promise.pending()
        fn vow.callback
        vow.promise
      else
        Promise.try fn

  streamClosure: (name, body) ->
    filter = @project.filters[name]
    throw new Error("Filter not found: #{name}") unless filter

    # command: [
    #   coffee: { $when: "path.extname === '.coffee'" }
    #   dest: 'build'
    # ]

    whenMode = ""
    if _.isArray(body)
      args = body
    else if _.isString(body)
      # function redirection
      if body[0] == '('
        @log.error "TODO function declaration"
      else
        args = [body]
    else if _.isPlainObject(body)
      whenMode = body.$mode if body.$mode

      if body.$when
        args = [
          stream: filter
          options: _.omit("$when")
          cond: {$when: body.$when}
        ]
        filter = ifcond
      else
        args = [body]
    else
      args = [body]

    # used by watch to optimize file processing.
    if filter.__meta?.isAggregator
      @rebuild = "all"

    # eg coffee.apply coffee, [{bare: true}]
    #filter.apply filter, args
    {name, filter, args, whenMode}


  normalizeProperties: (definition) ->
    for prop, aliases of aliasTaskProps
      if !definition[prop]
        for alias in aliases
          if definition[alias]
            definition[prop] = definition[alias]
            break

      # get rid of aliasses
      for alias in aliases
        delete definition[alias]
    definition


  ###
  # Creates a closure that returns an array of streams
  ###
  createPipeline: (pipeline) ->
    throw new Error("@command is not a pipeline array") unless _.isArray(pipeline)
    that = @
    log = @log

    infos = []
    for filter, i in pipeline
      for name, args of filter
        infos.push that.streamClosure(name, args)
        break

    ###
    # Return array of stream filters with their arguments applied.
    ###
    return (mode) ->
      filters = _.filter infos, (info) ->

        # Each filter may specify to run only in specific mode(s)
        whenMode = info.whenMode
        whenModes = _.compact(whenMode.split(/\s+/))
        if whenModes.length
          if whenModes[0] == '!'
            skip = true if whenModes[0].slice(1) == mode
          else
            skip = true if whenModes.indexOf(mode) < 0

        if skip
          log.debug "#{info.name} skipped, runs when #{whenMode}"
        else
          log.debug "#{info.name} used"
        !skip

      _.map filters, (info) ->
        info.filter.apply info.filter, info.args


  normalizeCommand: (definition) ->
    if !definition.command
      for alias in aliasTaskProps.command
        if definition[alias]
          definition.command = definition[alias]
          break

    # get rid of aliasses
    for alias in aliasTaskProps.command
      delete definition[alias]

    if _.isFunction(definition.command)
      # do nothing, it already is in expected format
      definition.command = @wrapInPromise(definition.command)

    # command: "(A.foo arg1 arg2)"
    else if _.isString(definition.command)
      definition.command = @compileFunctionString(definition.command)

    else
      throw new Error("Command must be a function or function meta string")


  normalizePipeline: (definition) ->
    if !definition.pipeline
      for alias in aliasTaskProps.pipeline
        if definition[alias]
          definition.pipeline = definition[alias]
          break

    # get rid of aliases
    for alias in aliasTaskProps.pipeline
      delete definition[alias]

    # command: [{tap: "(A.changeAsset arg1, arg2)"}]
    if _.isArray(definition.pipeline)
      definition.pipeline = @createPipeline(definition.pipeline)
    else if _.isFunction(definition.pipeline)
      # do nothing, it's already in the expected form
    else
      throw new Error("Pipeline must be array of meta objects")

  ###
  # Allows abbreviated identifiers for user friendliness
  #
  # @param {Object} definition The task defintion.
  #
  # @example
  #
  # sometask: DEFINITION
  ###
  normalizeDefinition: (definition) ->
    if _.isString(definition)
      # task: "(A.foo arg)"   // run a function when task is called
      if definition[0] == '('
        definition = command: definition, dependencies: []
      # task: "task1 task2"
      else
        definition = dependencies: definition.split(/\s+/)

    # task: "a b c"         // run dependencies task a, task b and task c in sequence
    else if _.isArray(definition)
      definition = dependencies: definition

    # task: function() {}
    else if _.isFunction(definition)
      definition = command: definition, dependencies: []

    else
      throw new Error("Task definition must be string, array or function") unless _.isPlainObject(definition)

    definition = @normalizeProperties(definition)

    @normalizeCommand(definition) if definition.command
    @normalizePipeline(definition) if definition.pipeline

    # Several short cuts to create a file set
    if !definition.files
      definition.files = include: [], exclude: []
    else
      # task:
      #   files: "foo/**/*.ext
      if typeof definition.files == "string"
        files = definition.files
        if files.indexOf(' ') >= 0
          log.info "Space found in files string: #{definition.files}, use array?"
        definition.files =
          include: [files]

      # task:
      #   files: ["foo/**/*.ext]
      if Array.isArray(definition.files)
        definition.files =
          include: definition.files

      # task:
      #   files:
      #     include: "foo/**/*.ext
      if typeof definition.files.include == "string"
        definition.files.include =  [definition.files.include]

      # check for exclusions
      if typeof definition.files.exclude == "string"
        definition.files.exclude = [definition.files.exclude]

      if !Array.isArray(definition.files.exclude)
        definition.files.exclude =  []

      removePatterns = []
      if Array.isArray(definition.files.include)
        for pattern in definition.files.include
          if pattern.indexOf("!") == 0
            excludePattern = pattern.slice(1)
            #removePatterns.push excludePattern
            removePatterns.push pattern

            if Str.endsWith(excludePattern, '/')
              definition.files.exclude.push excludePattern
              definition.files.exclude.push excludePattern + "**/*"
            else
              definition.files.exclude.push excludePattern

      # remove exclusions
      definition.files.include = _.reject(definition.files.include, (pattern) -> removePatterns.indexOf(pattern) >= 0)

      #console.dir definition.files


    definition.description ?= "Runs #{@name} task"
    @normalizeDependencies definition

    definition

  normalizeDependencies: (definition) ->
    if _.isString(definition.dependencies)
      definition.dependencies = definition.dependencies.split(/\s+/)

    definition.dependencies ?= []


  ###
  # Watch files in `files.watch` or `files.include` and execute this
  # tasks whenever any matching files changes.
  ###
  watchFiles: (cb) ->
    return if @watching
    @watching = true

    # dir/**/*.ext => match[1] = dirname, match[2] = extname
    subdirRe = /(.*)\/\*\*\/\*(\..*)$/

    # dir/*.ext => match[1] = dirname, match[2] = extname
    dirRe = /(.*)\/\*(\..*)$/

    # Watch patterns can be inferred from `files.include` but in
    # some cases, a single file includes many other files.
    # In this situation, the dependent files should be monitored
    # and declared via `files.watch` to trigger building the task properly.
    patterns = if @watch.length > 0 then @watch else @files.include
    return unless patterns.length

    paths = []
    for pattern in patterns
      dir = Str.strLeft(pattern, '*')
      paths.push(dir)

    paths = _.unique(paths)
    watcher = Chokidar.watch(paths, ignored: /^\./, ignoreInitial: true, persistent: true)

    that = @
    log = @log
    checkExecute = (action, path) ->
      for pattern in patterns
        if minimatch(path, pattern)
          log.debug "#{path} #{action}"
          that.execute(path, true)

    watcher.on "add", (path) -> checkExecute("added", path)
    watcher.on "change", _.debounce ((path) -> checkExecute("changed", path)), 300
    # watcher.on 'unlink', (path) -> log.debug "`#{path}` removed"
    # watcher.on 'error', (path) -> log.debug "`#{path}` errored"

    @log.info "Watching #{paths.join(', ')} ..."

  _executeFunction: (fn) ->
    that = @
    watch = @project.argv.watch

    # function(argv, cb)  // play nice with majority who use callbacks
    Promise.try(fn)


  ###
  # Computes the sources needed when executing. Initially the files glob is
  # used. In watch mode, a change may only require compiling a single file.
  ###
  sources: ->
    if @rebuild == "all" or @changeset.length is 0
      sources = @files.include.concat(_.map(@files.exclude, (pattern) -> "!" + pattern))
      #console.log sources
      sources
    else
      changeset = @changeset
      @changeset = []
      changeset

  _executePipeline: (pipeline, mode=@mode) ->
    throw new Error("pipeline is not a function") unless _.isFunction(pipeline)
    vow = Promise.pending()
    log = @log
    last = null
    filters = _.compact(pipeline(mode))
    that = @
    rejected = false


    if filters.length > 0
      start = Gulp.src(that.sources())
      start.on "error", (err) ->
        rejected = true
        console.error err
        vow.reject err

      filters.reduce (previous, filter) ->
        filter.on "error", (err) ->
          rejected = true
          console.error err
          vow.reject err

        previous.pipe filter
        last = filter
      , start

      last.on "end", ->
        if !rejected
          vow.fulfill()
    else
      log.info "no filters to run in #{mode}"
      vow.fulfill()

    vow.promise


  ###
  # Executes this task's environment pipeline.
  #
  # @param {String} filename Sent by the watch listener when a file changes as
  #                          opposed to the runner, which calls execute without
  #                          a path.
  ###
  execute: (filename) =>
    @changeset.push filename if filename?

    if not @watching and @ran
      @log.debug("skipping, already ran")
      return

    log = @log
    that = @

    if !@command and !@pipeline
      # Some tasks aggregate dependencies only
      if @dependencies.length > 0
        return
      else
        @log.warn "command|pipeline missing"
        return

    # the project writes a message when not watching, give some feedback when watching
    logStatus = (promise) ->
      startTime = Date.now()

      # filename is set by watch listener, this logic is only when watching
      if filename
        promise.then ->
          ms = (Date.now() - startTime)
          log.info if that.rebuild is "all" then "rebuilt all #{ms} ms" else "rebuilt #{filename} #{ms} ms"
        promise.catch (err) ->
          # do nothing with it, error was printed in executePipeline
        # promise.catch (err) ->
        #   log.error if err.stack then err.stack else err

      promise

    @ran = true
    if _.isFunction(@command)
      logStatus @_executeFunction(@command)
    else if _.isFunction(@pipeline)
      logStatus @_executePipeline(@pipeline)
    else
      @log.error "Command is not a function or array pipeline", @__definition


  ###
  # Tasks have a compressed form in which the body defines 1 or more tasks
  # based on the mode.
  #
  # @param options {
  #   argv {Object} The parsed command line argv.
  #   name {string} Name of the task.
  #   definition {Object} The body definition of the task.
  # }
  #
  # @example
  #
  # build:
  #   def: ...
  #   release: ...
  #
  # Results in two tasks:
  #
  # build
  # build@release
  ###
  @create = (options) ->
    {name, definition, project} = options
    tasks = {}
    definition = _.clone(definition)
    reserved = _.flatten(_.keys(aliasTaskProps).concat(_.values(aliasTaskProps)))
    reserved.push "rebuild"

    if _.isPlainObject(definition)# and !_.isArray(definition)
      for k, v of definition
        continue if reserved.indexOf(k) > -1
        k
        # eg release task
        # create release task by cloning it
        newdef = _.clone(definition)

        # delete it from existing task
        delete definition[k]

        # delete other commands but track which one it is
        # to replace it
        which = ""
        for action in ["pipeline", "cmd", "command"]
          if newdef[action]?
            which = action
            delete newdef[action]

        # create the new task with pipeline or command
        if !which
          throw new Error("Task must have `command` or `pipeline`")
        newdef[which] = v
        newname = name + '@' + k       # k becomes the mode
        tasks[newname] = new Task({name: newname, definition: newdef, project})

    tasks["#{name}"] = new Task({name, definition, project})
    tasks


module.exports = Task
