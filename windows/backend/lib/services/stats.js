// Generated by IcedCoffeeScript 1.8.0-d
(function() {
  var CheckInterval, Debug, DebugCheckInterval, DebugPingInterval, LRStats, PREF_LANG_PING, PingInterval, debug, http, unixTime;

  debug = require('debug')('livereload:stats');

  http = require('http');

  PREF_LANG_PING = 'stats.AppNewsKitLastPingTime';

  Debug = false;

  PingInterval = 24 * 60 * 60;

  CheckInterval = 30 * 60;

  DebugPingInterval = 60.;

  DebugCheckInterval = 10.;

  unixTime = function() {
    return Math.floor(+new Date() / 1000);
  };

  module.exports = LRStats = (function() {
    function LRStats(preferences) {
      this.preferences = preferences;
    }

    LRStats.prototype.doPingServer = function(scheduled) {
      var options, version;
      version = LR.version;
      options = {
        host: 'ping.livereload.com',
        port: 80,
        path: "/news.json?apiver=1&platform=windows&v=" + version + "&iv=" + version + "&scheduled=" + (scheduled && 1 || 0)
      };
      debug("Pinging server... (http://" + options.host + options.path + ")");
      return http.get(options, (function(_this) {
        return function(res) {
          debug("Server ping successful, response code = " + res.statusCode);
          if (res.statusCode === 200) {
            return _this.preferences.set(PREF_LANG_PING, unixTime());
          }
        };
      })(this)).on('error', (function(_this) {
        return function(err) {
          return debug("ERROR: Server ping failed: " + err.message);
        };
      })(this));
    };

    LRStats.prototype.pingServer = function(force) {
      return this.preferences.get(PREF_LANG_PING, (function(_this) {
        return function(value) {
          var schedule;
          schedule = value && unixTime() > value + PingInterval;
          if (Debug && value && (unixTime() > value + DebugPingInterval)) {
            force = true;
          }
          if (schedule || force) {
            return _this.doPingServer(schedule);
          }
        };
      })(this));
    };

    LRStats.prototype.startup = function() {
      this.pingServer(true);
      return setInterval(((function(_this) {
        return function() {
          return _this.pingServer(false);
        };
      })(this)), (Debug && DebugCheckInterval || CheckInterval) * 1000);
    };

    return LRStats;

  })();

}).call(this);
