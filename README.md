# gee

Simpler builds using [gulp](https://github.com/gulpjs/gulp) filters.


## Motivation

Lots of build systems out there. Grunt, Gulp ... too low level. What you get

* gulp filters (node streams)
* autowatch (-w flag)
* display errors and continue when watching
* build modes for test, release ...
* efficient rebuild when watching
* imperative or declaractive (JSON) project scripts
* serve files locally with http/https

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
  var strtap = gee.strtap;

  function addHeader() {
    /* use strtap to change a file using strings, return true to update */
    return strtap(function(file) {
      var header = '/*** YOUR HEADER */';
      file.contents = header + '\n' + file.contents;
      return true;
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
      pipe: function() {
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

