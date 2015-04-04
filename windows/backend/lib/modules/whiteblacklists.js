// Generated by IcedCoffeeScript 1.8.0-d
(function() {
  var BLACK_SKEL, Path, RelPathList, RelPathSpec, WHITE_SKEL, debug, fs, identity, invertor, loadList, loadLists, tryReadTextFileSync, _ref;

  debug = require('debug')('livereload:whiteblack');

  Path = require('path');

  fs = require('fs');

  _ref = require('pathspec'), RelPathList = _ref.RelPathList, RelPathSpec = _ref.RelPathSpec;

  WHITE_SKEL = "# add file specs here to monitor them  (use .gitignore syntax; LR restart required):\n#\n# *.more\n# stylesheets/**/*.supercss" + "\n";

  BLACK_SKEL = "# add file specs here to exclude them from monitoring  (use .gitignore syntax; overrides included.txt; LR restart required):\n#\n# *.bad\n# logs/\n# offending/file.js" + "\n";

  tryReadTextFileSync = function(path) {
    var e;
    try {
      return fs.readFileSync(path, 'utf8');
    } catch (_error) {
      e = _error;
      return null;
    }
  };

  identity = function(line) {
    return line;
  };

  invertor = function(line) {
    return '!' + line;
  };

  loadList = function(path, mapper, createSkeleton) {
    var body, lines;
    if (body = tryReadTextFileSync(path)) {
      lines = body.replace(/\r/g, '').split("\n").map(function(line) {
        return line.replace(/(^|\s)#.*$/, '').trim();
      }).filter(function(line) {
        return !!line;
      }).map(mapper);
      return RelPathList.parse(lines);
    } else {
      if (createSkeleton) {
        try {
          fs.writeFileSync(path, createSkeleton);
        } catch (_error) {}
      }
      return RelPathList.parse([]);
    }
  };

  loadLists = function(context, fileName, mapper, createSkeleton) {
    var custom, list;
    list = loadList(Path.join(context.paths.res, fileName), mapper, null);
    if (custom = loadList(Path.join(context.paths.appData, fileName), mapper, createSkeleton)) {
      list.include(custom);
    }
    return list;
  };

  exports.loadMonitoredFilesList = function(context) {
    var black, white;
    white = loadLists(context, 'included.txt', identity, WHITE_SKEL);
    black = loadLists(context, 'excluded.txt', invertor, BLACK_SKEL);
    white.include(black);
    debug("Final list of monitored filespecs: " + white);
    return white;
  };

}).call(this);
