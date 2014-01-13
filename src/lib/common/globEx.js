var glob = require("glob");
var async = require("async");
var _ = require("lodash");
var minimatch = require("minimatch");

function array(arr) {
  return Array.isArray(arr) ? arr : [arr];
}

function resolveGlobs(patterns, excludePatterns, options) {
  options = options || {};
  return array(patterns).reduce(function (fns, pattern) {
    fns.push(function (done) {
      glob(pattern, options, function (err, matches) {
        if (!err && options.strict && matches.length === 0) {
          done(new Error("'" + pattern + "' matched no files"));
        } else {
          excludePatterns.forEach(function(excludePattern) {
            matches = _.reject(matches, function(filename) {
              if (_.isString(excludePattern)) {
                return minimatch(filename, excludePattern, {matchBase: true});
              } else if (excludePattern instanceof 'RegExp') {
                return excludePattern.test(filename);
              } else {
                return false;
              }
            });
          });
          done(err, matches);
        }
      });
    });
    return fns;
  }, []);
}

function processSingle(callback) {
  return function (err, matches) {
    callback(err, _.uniq(_.flatten(_.toArray(matches))));
  };
}

module.exports = function (patterns, excludePatterns, options, cb) {
  if (typeof options === "function") {
    cb = options;
    options = null;
  }
  async.parallel(resolveGlobs(patterns, excludePatterns, options), processSingle(cb));
}
