# gee

A simpler build system built on [gulp](https://github.com/gulpjs/gulp) filters.


## Motivation

Lots of build systems out there. Grunt, Gulp ... too low level. What you get

*   Uses Gulp filters
*   Builds modes - Reuse source globs in test, release builds
*   Watch is built in
*   Efficient rebuilding on watch, can process send single file
*   Useful help screen
*   Serve files locally with http and https w/ valid cert

    Useful for testing your project, plugins for cross-site issues

*   Use `tap` for simple tasks and debugging.
*   Project files can also be in JSON/CSON/YAML for integration into IDEs

JSON format is supported and will be documented with Projmate GUI.


## Install

Install the launcher

    npm install gee-cli -g

Pin a specific version of gee to your project. For now use github version

    npm install geejs/gee


## Projfile

`gee` searches the current directory and up for a project file named `Projfile.js`
or `Projfile.coffee`.

CoffeeScript example, [example/simple.coffee](example/simple.coffee)

JavaScript example

```js
exports.project = function(gee) {
  var argv = gee.argv;
  var tap = gee.tap;

  function addHeader() {
    return tap(function(file) {
      var header = '/*** YOUR HEADER */';
      file.contents = Buffer.concat([new Buffer(header), file.contents]);
    });
  };

  function ifCoffee() {
    return tap(function(file, t) {
      if (Path.extname(file.path) === '.coffee')
        return t.through(coffee, []);
    });
  };

  return {
    'default': 'clean async asyncPromise scripts',

    clean: function() {
      $.rm('-rf', 'build');
    },

    'clean@release': function() {
      $.rm('-rf', 'dist');
    },

    scripts: {
      src: 'src/**/*.{coffee,js}',
      pipeline: function() {
        return [ifCoffee(), dest('build')];
      },
      release: function() {
        return [ifCoffee(), uglify(), addHeader(), dest('dist')];
      }
    },

    helloArguments: function() {
      console.log('Hello ' + argv.message);
    },

    async: function(next) {
      process.nextTick(function() {
        console.log('async');
        next();
      });
    },

    asyncPromise: function() {
      var vow = Promise.pending();
      process.nextTick(function() {
        console.log('promise');
        vow.fulfill();
      });
      return vow.promise;
    }
  };
};
```

Since this is in the example folder, use custom file `-f` option.

To see tasks

    gee run -f example/simple.js -?

To run sample in watch mode

    gee run -f example/simple.js -w

To run sample in release mode

    gee run -f example/simple.js -m release


## License

The MIT License (MIT)

Copyright (c) 2013, 2014 Mario Gutierrez <mario@mgutz.com>

See the file COPYING for copying permission.

