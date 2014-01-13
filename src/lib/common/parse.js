var _ = require('lodash');
var grab = require('./grab');

/**
 * Parses a string for white space delimited arguments. Single
 * quote strings are allowed, use two single quotes to escape.
 */
function parseArgs(str, ignoreQuotes) {
  var args = [];
  var readingPart = false;
  var part = '', nextCh='', ch='', skipPush=-1;

  function addPart() {
    args.push(part);
    part = '';
  }

  for (var i=0; i<str.length; i++) {
    ch = str[i];

    if (ch === ' ' && !readingPart) {
      if (skipPush !== i) {
        addPart();
      }
    } else {
      nextCh = i < str.length - 1 ? str[i+1] : '';
      if (ch === '\'' && nextCh === '\'') {
        part += ch;
        i += 1;
      } else if (ch === '\'' && !ignoreQuotes) {
        readingPart = !readingPart;
        if (!readingPart) {
          addPart();
          skipPush = i+1;
        }
      } else {
        part += ch;
      }
    }
  }

  if (part) {
    args.push(part);
  }
  return args;
}


/**
 * Parses a function string into its pkg, fn and arg parts.
 *
 * @example
 *
 *  parseFunc("(A.foo 1 'no you don''t')") => { pkg: 'A', fn: 'foo', args: ['1', 'no you don\'t'] }
 */
function parseFunc(s) {
  var l = s.length;

  if (s[0] !== '(' && s[l - 1] !== ')') return null;
  try {
    var line = s.slice(1, l-1);
    var parts = parseArgs(line);

    var pkg_fn = parts[0].split('.');
    var args = [];
    if (parts.length > 1) {
      args = parts.slice(1);
    }

    return { pkg: pkg_fn[0], fn: pkg_fn[1], args: args };
  } catch (e) {
    return null;
  }
}

/**
 * Simple expression parser.
 */
function evalExpression(s, object) {
  var parts = parseArgs(s);
  var lhs, op, rhs;
  if (parts.length === 3) {
    lhs = grab(object, parts[0]);
    op = parts[1];
    rhs = parts[2];
    if (typeof lhs === 'undefined') {
      throw new Error('File property not found:', l);
    }


    if (op === '===') {
      return lhs ===  rhs;
    } else if (op === '==') {
      return lhs == rhs;
    } else if (op === '!=') {
      return lhs != rhs;
    } else if (op === '!==') {
      return lhs !== rhs;
    }
  } else if (parts.length === 1) {
    lhs = grab(obj, parts[0]);
    return Boolean(lhs);
  }
  return false;
}

module.exports = {
  parseFunc: parseFunc,
  evalExpression: evalExpression
};
