var Transform = require('minilog/lib/common/transform');
var style = require('minilog/lib/node/formatters/util').style;
var util = require('util');
var levels = {
  'debug': 'dbg',
  'info': 'inf',
  'warn': 'wrn',
  'error': 'err'
};

function FormatMinilog(plain) {
  this._indent = '';
  this.plain = plain;
}
Transform.mixin(FormatMinilog);

var maxName = 16;

FormatMinilog.prototype.write = function(name, level, args) {
  var colors = { debug: 'blue', info: 'cyan', warn: 'yellow', error: 'red' };
  var pad = '                ';
  if (name.length > maxName) {
    maxName = name.length;
    pad = '                                        '.slice(0, maxName);
  }
  name = (name + pad).slice(0, maxName);

  if (this.plain) {
    name = name ? name +' ' : '';
    level = level ? levels[level] + ' ' : '';
    args = args.map(function(item) {
             return (typeof item == 'string' ? item : util.inspect(item, null, 3, true));
           }).join(' ');
  } else {
    name = (name ? style(name +' ', level === 'error' ? 'red' : 'green') : '');
    level = (level ? style(levels[level], colors[level]) + ' ' : '');
    args = args.map(function(item) {
             return (typeof item == 'string' ? item : util.inspect(item, null, 3, true));
           }).join(' ');
  }
  this.emit('item', name + level + this._indent + args + '\n');
};

FormatMinilog.prototype.indent = function() {
  this._indent += '  ';
}

FormatMinilog.prototype.unindent = function() {
  this._indent = this._indent.slice(0, -2);
}


module.exports = FormatMinilog;
