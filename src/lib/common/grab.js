// Copyright (c) 2013 Andrew Luetgers, MIT License
var _ = require('lodash');

// cache regexes and strings to save some garbage
var grabReQuo = /"|'/g;
var grabReOpBr = /\[/g;
var grabReClBr = /\]/g;
var emptyStr = "";
var period = ".";

// handle blah.foo["stuff"][0].value or blah.foo.stuff.0.value
// does not support property names containing periods or quotes or [ or ]
function _grabStr(obj, path, alt, verbose) {
  path = path.replace(grabReQuo, emptyStr).replace(grabReOpBr, period).replace(grabReClBr, emptyStr).split(period);
  // results in ["blah", "foo", "stuff", 0, "value"]
  var val = obj, altVal;
  _.every(path, function(pathStr, idx) {
    //console.log("val at", val, pathStr);
    val = val[pathStr]; // traverse deeper into the object
    if ((idx < path.length-1 && !val) || val === undefined || val === "" || val === null) {
      altVal = _.isFunction(alt) ? alt(obj, path, idx) : alt;
      return false;
    } else {
      return true;
    }
  });

  return verbose ? {val: val, altVal: altVal} : altVal || val;
}

/* handle multi selection on one object syntax
     var data = {blah: {foo: {test: ["hi"]}}};
     _.grab(data, {
      foo: "blah.foo",
      test: "blah.foo.test",
      missing: ["blah[0].test", "a default value"]
      });
*/
function _grabObj(obj, path) {
  var res = {};
  _.each(path, function(val, key) {
    if (_.isArray(val)) {
      res[key] =  _.grab(obj, val[0], val[1]); // handle default values as in missing above
    } else {
      res[key] = _.grab(obj, val);
    }
  });

  return res;
}

// handle an array of paths to try
function _grabArr(obj, path, alt) {
  var val = {};
  _.all(path, function(_path) {
    val = _.grab(obj, _path, alt, true);
    return !val.val; // if no value continue on to the next path
  });
  console.log("_grabArr", val.val || val.altVal, val);
  return  (val.val || val.val === 0 || val.val === false) ? val.val : val.altVal;
}


function grab(obj, path, alt, verbose) {

  if (!obj) {return alt;}

  // handle blah.foo["stuff"][0].value or blah.foo.stuff.0
  if (typeof path === "string") {
    return _grabStr(obj, path, alt, verbose);

    // handle an array of paths to try
  } else if (_.isArray(path)) {
    return _grabArr(obj, path, alt, verbose);

    // handle multi selection on one object syntax
  } else if (_.isObject(path)) {
    return _grabObj(obj, path);
  }

  return alt;
}

module.exports = grab;
