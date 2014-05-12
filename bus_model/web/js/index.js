(function e(t,n,r){function s(o,u){if(!n[o]){if(!t[o]){var a=typeof require=="function"&&require;if(!u&&a)return a(o,!0);if(i)return i(o,!0);throw new Error("Cannot find module '"+o+"'")}var f=n[o]={exports:{}};t[o][0].call(f.exports,function(e){var n=t[o][1][e];return s(n?n:e)},f,f.exports,e,t,n,r)}return n[o].exports}var i=typeof require=="function"&&require;for(var o=0;o<r.length;o++)s(r[o]);return s})({1:[function(require,module,exports){
exports.loadTrips = function() {
  return Q($.getJSON('trips.json'))["catch"](function(err) {
    return console.error(err);
  });
};


},{}],2:[function(require,module,exports){
$(function() {
  console.log('hello world');
  return require('./data.coffee').loadTrips().then(function(trips) {
    require('./map.js').show(trips, '#route-8-map');
    require('./trip-plot.coffee').show(trips);
    return require('./point-model.coffee').show(trips);
  });
});


},{"./data.coffee":1,"./map.js":3,"./point-model.coffee":5,"./trip-plot.coffee":6}],3:[function(require,module,exports){

exports.show = function(trips, canvas) {
    var width = $(canvas).width(),
        height = $(canvas).height(),
        prefix = prefixMatch(["webkit", "ms", "Moz", "O"]);

    var tile = d3.geo.tile()
        .size([width, height]);

    var projection = d3.geo.mercator()
        .scale((1 << 20) / 2 / Math.PI)
        .translate([-width / 2, -height / 2]); // just temporary

    var tileProjection = d3.geo.mercator();

    var tilePath = d3.geo.path()
        .projection(tileProjection);

    var routePath = d3.geo.path().projection(projection);

    var zoom = d3.behavior.zoom()
        .scale(projection.scale() * 2 * Math.PI)
        .scaleExtent([1 << 20, 1 << 25])
        .translate(projection([-71.0752, 42.335]).map(function(x) { return -x; }))
        .on("zoom", zoomed);

    var map = d3.select(canvas)
        .attr("class", "map")
        .call(zoom)
        .on("mousemove", mousemoved);

    var layer = map.append("div")
        .attr("class", "layer");

    var routeGeo = {type: 'LineString', coordinates: trips[0].true_path};
    var route = map.append("div")
        .attr("class", "route")
        .append('svg')
        .attr('width', width + 'px')
        .attr('height', height + 'px')
        .selectAll('path')
        .data([routeGeo])
        .enter()
        .append('path');
    
    route
        .attr('class', 'route-path')
        .attr('d', routePath);

    var info = map.append("div")
        .attr("class", "coord-info");

    zoomed();

    function zoomed() {
      var tiles = tile
          .scale(zoom.scale())
          .translate(zoom.translate())
          ();

      projection
          .scale(zoom.scale() / 2 / Math.PI)
          .translate(zoom.translate());

      route.attr('d', routePath);

      var image = layer
          .style(prefix + "transform", matrix3d(tiles.scale, tiles.translate))
        .selectAll(".tile")
          .data(tiles, function(d) { return d; });

      image.exit()
          .each(function(d) { this._xhr.abort(); })
          .remove();

      image.enter().append("svg")
          .attr("class", "tile")
          .style("left", function(d) { return d[0] * 256 + "px"; })
          .style("top", function(d) { return d[1] * 256 + "px"; })
          .each(function(d) {
            var svg = d3.select(this);
            this._xhr = d3.json("http://" + ["a", "b", "c"][(d[0] * 31 + d[1]) % 3] + ".tile.openstreetmap.us/vectiles-highroad/" + d[2] + "/" + d[0] + "/" + d[1] + ".json", function(error, json) {
              var k = Math.pow(2, d[2]) * 256; // size of the world in pixels

              tilePath.projection()
                  .translate([k / 2 - d[0] * 256, k / 2 - d[1] * 256]) // [0�,0�] in pixels
                  .scale(k / 2 / Math.PI);

              svg.selectAll("path")
                  .data(json.features.sort(function(a, b) { return a.properties.sort_key - b.properties.sort_key; }))
                .enter().append("path")
                  .attr("class", function(d) { return d.properties.kind; })
                  .attr("d", tilePath);
            });
          });
    }

    function mousemoved() {
      info.text(formatLocation(projection.invert(d3.mouse(this)), zoom.scale()));
    }

    function matrix3d(scale, translate) {
      var k = scale / 256, r = scale % 1 ? Number : Math.round;
      return "matrix3d(" + [k, 0, 0, 0, 0, k, 0, 0, 0, 0, k, 0, r(translate[0] * scale), r(translate[1] * scale), 0, 1 ] + ")";
    }

    function prefixMatch(p) {
      var i = -1, n = p.length, s = document.body.style;
      while (++i < n) if (p[i] + "Transform" in s) return "-" + p[i].toLowerCase() + "-";
      return "";
    }

    function formatLocation(p, k) {
      var format = d3.format("." + Math.floor(Math.log(k) / 2 - 2) + "f");
      return (p[1] < 0 ? format(-p[1]) + "deg S" : format(p[1]) + "deg N") + " "
           + (p[0] < 0 ? format(-p[0]) + "deg W" : format(p[0]) + "deg E");
    }
};

},{}],4:[function(require,module,exports){
var EARTH_RADIUS;

EARTH_RADIUS = 6378;

exports.Path = (function() {
  function Path(points) {
    var i, latScale, lats, lonScale, lons, minLat, minLon, p;
    lons = (function() {
      var _i, _len, _results;
      _results = [];
      for (_i = 0, _len = points.length; _i < _len; _i++) {
        p = points[_i];
        _results.push(p[0]);
      }
      return _results;
    })();
    lats = (function() {
      var _i, _len, _results;
      _results = [];
      for (_i = 0, _len = points.length; _i < _len; _i++) {
        p = points[_i];
        _results.push(p[1]);
      }
      return _results;
    })();
    minLon = 0;
    minLat = 0;
    lonScale = EARTH_RADIUS * 2 * Math.PI / 360 * Math.cos(minLat * Math.PI / 180);
    latScale = EARTH_RADIUS * 2 * Math.PI / 360;
    this.points = (function() {
      var _i, _ref, _results;
      _results = [];
      for (i = _i = 0, _ref = points.length; 0 <= _ref ? _i < _ref : _i > _ref; i = 0 <= _ref ? ++_i : --_i) {
        _results.push([(lons[i] - minLon) * lonScale, (lats[i] - minLat) * latScale]);
      }
      return _results;
    })();
  }

  Path.prototype.speeds = function(times) {
    var dist, dt, i, x0, x1, y0, y1, _i, _ref, _ref1, _ref2, _results;
    _results = [];
    for (i = _i = 0, _ref = times.length - 1; 0 <= _ref ? _i < _ref : _i > _ref; i = 0 <= _ref ? ++_i : --_i) {
      _ref1 = this.points[i], x0 = _ref1[0], y0 = _ref1[1];
      _ref2 = this.points[i + 1], x1 = _ref2[0], y1 = _ref2[1];
      dist = Math.sqrt(Math.pow(x1 - x0, 2) + Math.pow(y1 - y0, 2));
      dt = (times[i + 1] - times[i]) / (60 * 60);
      _results.push(dist / dt);
    }
    return _results;
  };

  return Path;

})();


},{}],5:[function(require,module,exports){
var Path, gpsStd, margin;

Path = require('./path.coffee').Path;

margin = {
  top: 20,
  right: 20,
  bottom: 40,
  left: 50
};

gpsStd = 20;

exports.show = function(_arg) {
  var canvas, colorScale, current, delta, deltaLength, ds, gpsInput, height, i, length, line, next, onMouse, p, path, pathParts, paths, remaining, true_path, update, width, xScale, yScale;
  true_path = _arg[0].true_path;
  gpsInput = $('#gps-std');
  gpsInput.val(gpsStd);
  update = function() {
    var newVal;
    newVal = +gpsInput.val();
    if (!isNaN(newVal) && newVal > 0) {
      return gpsStd = +gpsInput.val();
    }
  };
  gpsInput.change(update);
  gpsInput.keyup(update);
  path = new Path(true_path);
  width = $('#point-model-canvas').width() - margin.left - margin.right;
  height = $('#point-model-canvas').height() - margin.top - margin.bottom;
  xScale = d3.scale.linear().range([0, width]).domain(d3.extent((function() {
    var _i, _len, _ref, _results;
    _ref = path.points.concat(path.points);
    _results = [];
    for (_i = 0, _len = _ref.length; _i < _len; _i++) {
      p = _ref[_i];
      _results.push(p[0]);
    }
    return _results;
  })()));
  yScale = d3.scale.linear().range([height, 0]).domain(d3.extent((function() {
    var _i, _len, _ref, _results;
    _ref = path.points.concat(path.points);
    _results = [];
    for (_i = 0, _len = _ref.length; _i < _len; _i++) {
      p = _ref[_i];
      _results.push(p[1]);
    }
    return _results;
  })()));
  canvas = d3.select('#point-model-canvas').append('g').attr('transform', "translate(" + margin.left + ", " + margin.right + ")");
  canvas.append('rect').attr('width', width).attr('height', height).style('fill', '#FFFFFF');
  line = d3.svg.line().x(function(_arg1) {
    var x, y;
    x = _arg1[0], y = _arg1[1];
    return xScale(x);
  }).y(function(_arg1) {
    var x, y;
    x = _arg1[0], y = _arg1[1];
    return yScale(y);
  });
  pathParts = [];
  ds = 0.05;
  remaining = path.points.slice(0);
  current = remaining.shift();
  while (remaining.length > 1) {
    next = remaining[0];
    delta = (function() {
      var _i, _len, _ref, _results;
      _ref = [0, 1];
      _results = [];
      for (_i = 0, _len = _ref.length; _i < _len; _i++) {
        i = _ref[_i];
        _results.push(next[i] - current[i]);
      }
      return _results;
    })();
    deltaLength = length = Math.sqrt(Math.pow(delta[0], 2) + Math.pow(delta[1], 2));
    while (length < ds && remaining.length > 1) {
      current = remaining.shift();
      next = remaining[0];
      delta = (function() {
        var _i, _len, _ref, _results;
        _ref = [0, 1];
        _results = [];
        for (_i = 0, _len = _ref.length; _i < _len; _i++) {
          i = _ref[_i];
          _results.push(next[i] - current[i]);
        }
        return _results;
      })();
      deltaLength = Math.sqrt(Math.pow(delta[0], 2) + Math.pow(delta[1], 2));
      length += deltaLength;
    }
    p = (ds - (length - deltaLength)) / deltaLength;
    current = [current[0] + p * delta[0], current[1] + p * delta[1]];
    pathParts.push(current);
  }
  pathParts = (function() {
    var _i, _ref, _results;
    _results = [];
    for (i = _i = 0, _ref = pathParts.length - 1; 0 <= _ref ? _i < _ref : _i > _ref; i = 0 <= _ref ? ++_i : --_i) {
      _results.push([pathParts[i], pathParts[i + 1]]);
    }
    return _results;
  })();
  paths = canvas.selectAll('.route-path model').data(pathParts);
  paths.exit().remove();
  paths.enter().append('path').attr('class', 'route-path model');
  paths.attr('d', line);
  colorScale = d3.scale.linear().clamp(true).domain([-80, 0]).range([d3.rgb(0x22, 0x22, 0x22), d3.rgb(0xFF, 0, 0)]);
  onMouse = function() {
    var gpsSquared, max, x, y, _ref;
    _ref = d3.mouse(this), x = _ref[0], y = _ref[1];
    x = xScale.invert(x);
    y = yScale.invert(y);
    gpsSquared = Math.pow(gpsStd / 1000, 2);
    max = -1e50;
    paths.each(function(_arg1) {
      var distSquared, logLike, px, py, _ref1;
      _ref1 = _arg1[0], px = _ref1[0], py = _ref1[1];
      distSquared = Math.pow(x - px, 2) + Math.pow(y - py, 2);
      logLike = -0.5 * distSquared / gpsSquared;
      if (logLike > max) {
        return max = logLike;
      }
    });
    return paths.each(function(_arg1) {
      var distSquared, logLike, px, py, _ref1;
      _ref1 = _arg1[0], px = _ref1[0], py = _ref1[1];
      distSquared = Math.pow(x - px, 2) + Math.pow(y - py, 2);
      logLike = -0.5 * distSquared / gpsSquared - max;
      return d3.select(this).style('stroke', colorScale(logLike));
    });
  };
  return canvas.on('mousemove', _.throttle(onMouse, 50, {
    leading: true,
    trailing: false
  }));
};


},{"./path.coffee":4}],6:[function(require,module,exports){
var Path, fillTripSelect, margin, pathCanvas, showPaths, showSpeeds, showTrip;

Path = require('./path.coffee').Path;

exports.show = function(trips) {
  return fillTripSelect(trips, showTrip);
};

margin = {
  top: 20,
  right: 20,
  bottom: 40,
  left: 50
};

showTrip = function(trip) {
  var path, truePath;
  path = new Path(trip.path);
  truePath = new Path(trip.true_path);
  showPaths(path, truePath);
  return showSpeeds(trip, path);
};

pathCanvas = null;

showPaths = function(path, truePath) {
  var circles, height, legend, line, p, realSvg, trueSvg, width, xScale, yScale;
  width = $('#trip-plot-canvas').width() - margin.left - margin.right;
  height = $('#trip-plot-canvas').height() - margin.top - margin.bottom;
  xScale = d3.scale.linear().range([0, width]).domain(d3.extent((function() {
    var _i, _len, _ref, _results;
    _ref = path.points.concat(truePath.points);
    _results = [];
    for (_i = 0, _len = _ref.length; _i < _len; _i++) {
      p = _ref[_i];
      _results.push(p[0]);
    }
    return _results;
  })()));
  yScale = d3.scale.linear().range([height, 0]).domain(d3.extent((function() {
    var _i, _len, _ref, _results;
    _ref = path.points.concat(truePath.points);
    _results = [];
    for (_i = 0, _len = _ref.length; _i < _len; _i++) {
      p = _ref[_i];
      _results.push(p[1]);
    }
    return _results;
  })()));
  if (pathCanvas == null) {
    pathCanvas = d3.select('#trip-plot-canvas').append('g').attr('transform', "translate(" + margin.left + ", " + margin.right + ")");
    legend = pathCanvas.append('g').attr('transform', "translate(0, " + height + ")");
    legend.append('rect').attr('class', 'scale-indicator').attr('x', 0).attr('y', 0).attr('width', xScale(1) - xScale(0)).attr('height', 2);
    legend.append('text').attr('class', 'scale-indicator').attr('x', 0).attr('y', 0).attr('dy', 12).text('1 km');
  }
  line = d3.svg.line().x(function(_arg) {
    var x, y;
    x = _arg[0], y = _arg[1];
    return xScale(x);
  }).y(function(_arg) {
    var x, y;
    x = _arg[0], y = _arg[1];
    return yScale(y);
  });
  trueSvg = pathCanvas.selectAll('.route-path').data([truePath.points]);
  trueSvg.exit().remove();
  trueSvg.enter().append('path').attr('class', 'route-path');
  trueSvg.attr('d', line);
  realSvg = pathCanvas.selectAll('.route-path-real-data').data([path.points]);
  realSvg.exit().remove();
  realSvg.enter().append('path').attr('class', 'route-path-real-data');
  realSvg.attr('d', line);
  circles = pathCanvas.selectAll('.real-data-point').data(path.points);
  circles.exit().remove();
  circles.enter().append('circle').attr('class', 'real-data-point').attr('r', 3);
  return circles.attr('cx', function(_arg) {
    var x, y;
    x = _arg[0], y = _arg[1];
    return xScale(x);
  }).attr('cy', function(_arg) {
    var x, y;
    x = _arg[0], y = _arg[1];
    return yScale(y);
  });
};

showSpeeds = function(_arg, path) {
  var data, height, i, line, speedCanvas, speeds, times, width, xAxis, xScale, yAxis, yScale;
  times = _arg.times;
  width = $('#trip-plot-speed-canvas').width() - margin.left - margin.right;
  height = $('#trip-plot-speed-canvas').height() - margin.top - margin.bottom;
  speeds = path.speeds(times);
  data = (function() {
    var _i, _ref, _results;
    _results = [];
    for (i = _i = 0, _ref = speeds.length; 0 <= _ref ? _i < _ref : _i > _ref; i = 0 <= _ref ? ++_i : --_i) {
      _results.push([times[i], speeds[i]]);
    }
    return _results;
  })();
  xScale = d3.scale.linear().range([0, width]).domain(d3.extent(times));
  yScale = d3.scale.linear().range([height, 0]).domain([0, d3.max(speeds)]);
  xAxis = d3.svg.axis().scale(xScale).orient('bottom');
  yAxis = d3.svg.axis().scale(yScale).orient('left');
  speedCanvas = d3.select('#trip-plot-speed-canvas');
  speedCanvas.selectAll('g').remove();
  speedCanvas = speedCanvas.append('g').attr('transform', "translate(" + margin.left + ", " + margin.right + ")");
  speedCanvas.append('g').attr('class', 'x axis').attr('transform', "translate(0, " + height + ")").call(xAxis).append('text').attr('y', 24).attr('dy', '0.71em').attr('x', width / 2).style('text-anchor', 'middle').text('Time [s]');
  speedCanvas.append('g').attr('class', 'y axis').call(yAxis).append('text').attr('transform', 'rotate(-90)').attr('y', -24).attr('dy', '-0.71em').attr('x', -height / 2).style('text-anchor', 'middle').text('Speed [kph]');
  line = d3.svg.line().x(function(_arg1) {
    var x, y;
    x = _arg1[0], y = _arg1[1];
    return xScale(x);
  }).y(function(_arg1) {
    var x, y;
    x = _arg1[0], y = _arg1[1];
    return yScale(y);
  });
  path = speedCanvas.selectAll('.speed-path').data([data]);
  path.exit().remove();
  path.enter().append('path').attr('class', 'speed-path');
  return path.attr('d', line);
};

fillTripSelect = function(trips, onSelect) {
  var i, select, _i, _ref;
  select = $('#trip-select');
  select.empty();
  for (i = _i = 0, _ref = trips.length; 0 <= _ref ? _i < _ref : _i > _ref; i = 0 <= _ref ? ++_i : --_i) {
    select.append("<option value=\"" + i + "\">" + i + "</option>");
  }
  select.change(function() {
    return onSelect(trips[+select.val()]);
  });
  return onSelect(trips[0]);
};


},{"./path.coffee":4}]},{},[2])
//# sourceMappingURL=data:application/json;base64,eyJ2ZXJzaW9uIjozLCJmaWxlIjoiZ2VuZXJhdGVkLmpzIiwic291cmNlcyI6WyJDOlxcVXNlcnNcXENoYXNlXFxBcHBEYXRhXFxSb2FtaW5nXFxucG1cXG5vZGVfbW9kdWxlc1xcYnJvd3NlcmlmeVxcbm9kZV9tb2R1bGVzXFxicm93c2VyLXBhY2tcXF9wcmVsdWRlLmpzIiwiQzpcXFVzZXJzXFxDaGFzZVxcRHJvcGJveFxcU2Nob29sXFxWaXN1YWxpemF0aW9uXFx2aXN1YWxpemF0aW9uLW9zc1xcYnVzX21vZGVsXFx3ZWJcXGRhdGEuY29mZmVlIiwiQzpcXFVzZXJzXFxDaGFzZVxcRHJvcGJveFxcU2Nob29sXFxWaXN1YWxpemF0aW9uXFx2aXN1YWxpemF0aW9uLW9zc1xcYnVzX21vZGVsXFx3ZWJcXGluZGV4LmNvZmZlZSIsIkM6L1VzZXJzL0NoYXNlL0Ryb3Bib3gvU2Nob29sL1Zpc3VhbGl6YXRpb24vdmlzdWFsaXphdGlvbi1vc3MvYnVzX21vZGVsL3dlYi9tYXAuanMiLCJDOlxcVXNlcnNcXENoYXNlXFxEcm9wYm94XFxTY2hvb2xcXFZpc3VhbGl6YXRpb25cXHZpc3VhbGl6YXRpb24tb3NzXFxidXNfbW9kZWxcXHdlYlxccGF0aC5jb2ZmZWUiLCJDOlxcVXNlcnNcXENoYXNlXFxEcm9wYm94XFxTY2hvb2xcXFZpc3VhbGl6YXRpb25cXHZpc3VhbGl6YXRpb24tb3NzXFxidXNfbW9kZWxcXHdlYlxccG9pbnQtbW9kZWwuY29mZmVlIiwiQzpcXFVzZXJzXFxDaGFzZVxcRHJvcGJveFxcU2Nob29sXFxWaXN1YWxpemF0aW9uXFx2aXN1YWxpemF0aW9uLW9zc1xcYnVzX21vZGVsXFx3ZWJcXHRyaXAtcGxvdC5jb2ZmZWUiXSwibmFtZXMiOltdLCJtYXBwaW5ncyI6IkFBQUE7QUNDQSxPQUFPLENBQUMsU0FBUixHQUFvQixTQUFBLEdBQUE7U0FDaEIsQ0FBQSxDQUFFLENBQUMsQ0FBQyxPQUFGLENBQVUsWUFBVixDQUFGLENBQ0EsQ0FBQyxPQUFELENBREEsQ0FDTyxTQUFDLEdBQUQsR0FBQTtX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ckRQLENBQUE7QUFBQSxFQXVEQSxJQUFJLENBQUMsSUFBTCxDQUFBLENBQVcsQ0FBQyxNQUFaLENBQUEsQ0F2REEsQ0FBQTtBQUFBLEVBd0RBLElBQUksQ0FBQyxLQUFMLENBQUEsQ0FDSSxDQUFDLE1BREwsQ0FDWSxNQURaLENBRUksQ0FBQyxJQUZMLENBRVUsT0FGVixFQUVtQixZQUZuQixDQXhEQSxDQUFBO1NBMkRBLElBQUksQ0FBQyxJQUFMLENBQVUsR0FBVixFQUFlLElBQWYsRUE1RFM7QUFBQSxDQWpGYixDQUFBOztBQUFBLGNBK0lBLEdBQWlCLFNBQUMsS0FBRCxFQUFRLFFBQVIsR0FBQTtBQUNiLE1BQUEsbUJBQUE7QUFBQSxFQUFBLE1BQUEsR0FBUyxDQUFBLENBQUUsY0FBRixDQUFULENBQUE7QUFBQSxFQUNBLE1BQU0sQ0FBQyxLQUFQLENBQUEsQ0FEQSxDQUFBO0FBRUEsT0FBUywrRkFBVCxHQUFBO0FBQ0ksSUFBQSxNQUFNLENBQUMsTUFBUCxDQUFlLGtCQUFBLEdBQWlCLENBQWpCLEdBQW9CLEtBQXBCLEdBQXdCLENBQXhCLEdBQTJCLFdBQTFDLENBQUEsQ0FESjtBQUFBLEdBRkE7QUFBQSxFQUlBLE1BQU0sQ0FBQyxNQUFQLENBQWMsU0FBQSxHQUFBO1dBQUcsUUFBQSxDQUFTLEtBQU0sQ0FBQSxDQUFBLE1BQU8sQ0FBQyxHQUFQLENBQUEsQ0FBRCxDQUFmLEVBQUg7RUFBQSxDQUFkLENBSkEsQ0FBQTtTQUtBLFFBQUEsQ0FBUyxLQUFNLENBQUEsQ0FBQSxDQUFmLEVBTmE7QUFBQSxDQS9JakIsQ0FBQSIsInNvdXJjZXNDb250ZW50IjpbIihmdW5jdGlvbiBlKHQsbixyKXtmdW5jdGlvbiBzKG8sdSl7aWYoIW5bb10pe2lmKCF0W29dKXt2YXIgYT10eXBlb2YgcmVxdWlyZT09XCJmdW5jdGlvblwiJiZyZXF1aXJlO2lmKCF1JiZhKXJldHVybiBhKG8sITApO2lmKGkpcmV0dXJuIGkobywhMCk7dGhyb3cgbmV3IEVycm9yKFwiQ2Fubm90IGZpbmQgbW9kdWxlICdcIitvK1wiJ1wiKX12YXIgZj1uW29dPXtleHBvcnRzOnt9fTt0W29dWzBdLmNhbGwoZi5leHBvcnRzLGZ1bmN0aW9uKGUpe3ZhciBuPXRbb11bMV1bZV07cmV0dXJuIHMobj9uOmUpfSxmLGYuZXhwb3J0cyxlLHQsbixyKX1yZXR1cm4gbltvXS5leHBvcnRzfXZhciBpPXR5cGVvZiByZXF1aXJlPT1cImZ1bmN0aW9uXCImJnJlcXVpcmU7Zm9yKHZhciBvPTA7bzxyLmxlbmd0aDtvKyspcyhyW29dKTtyZXR1cm4gc30pIiwiXHJcbmV4cG9ydHMubG9hZFRyaXBzID0gLT5cclxuICAgIFEgJC5nZXRKU09OICd0cmlwcy5qc29uJ1xyXG4gICAgLmNhdGNoIChlcnIpIC0+IGNvbnNvbGUuZXJyb3IgZXJyXHJcbiIsIlxyXG4kIC0+XHJcbiAgICBjb25zb2xlLmxvZyAnaGVsbG8gd29ybGQnXHJcbiAgICByZXF1aXJlKCcuL2RhdGEuY29mZmVlJykubG9hZFRyaXBzKClcclxuICAgIC50aGVuICh0cmlwcykgLT5cclxuICAgICAgICByZXF1aXJlKCcuL21hcC5qcycpLnNob3cgdHJpcHMsICcjcm91dGUtOC1tYXAnXHJcbiAgICAgICAgcmVxdWlyZSgnLi90cmlwLXBsb3QuY29mZmVlJykuc2hvdyB0cmlwc1xyXG4gICAgICAgIHJlcXVpcmUoJy4vcG9pbnQtbW9kZWwuY29mZmVlJykuc2hvdyB0cmlwc1xyXG4iLCJcclxuZXhwb3J0cy5zaG93ID0gZnVuY3Rpb24odHJpcHMsIGNhbnZhcykge1xyXG4gICAgdmFyIHdpZHRoID0gJChjYW52YXMpLndpZHRoKCksXHJcbiAgICAgICAgaGVpZ2h0ID0gJChjYW52YXMpLmhlaWdodCgpLFxyXG4gICAgICAgIHByZWZpeCA9IHByZWZpeE1hdGNoKFtcIndlYmtpdFwiLCBcIm1zXCIsIFwiTW96XCIsIFwiT1wiXSk7XHJcblxyXG4gICAgdmFyIHRpbGUgPSBkMy5nZW8udGlsZSgpXHJcbiAgICAgICAgLnNpemUoW3dpZHRoLCBoZWlnaHRdKTtcclxuXHJcbiAgICB2YXIgcHJvamVjdGlvbiA9IGQzLmdlby5tZXJjYXRvcigpXHJcbiAgICAgICAgLnNjYWxlKCgxIDw8IDIwKSAvIDIgLyBNYXRoLlBJKVxyXG4gICAgICAgIC50cmFuc2xhdGUoWy13aWR0aCAvIDIsIC1oZWlnaHQgLyAyXSk7IC8vIGp1c3QgdGVtcG9yYXJ5XHJcblxyXG4gICAgdmFyIHRpbGVQcm9qZWN0aW9uID0gZDMuZ2VvLm1lcmNhdG9yKCk7XHJcblxyXG4gICAgdmFyIHRpbGVQYXRoID0gZDMuZ2VvLnBhdGgoKVxyXG4gICAgICAgIC5wcm9qZWN0aW9uKHRpbGVQcm9qZWN0aW9uKTtcclxuXHJcbiAgICB2YXIgcm91dGVQYXRoID0gZDMuZ2VvLnBhdGgoKS5wcm9qZWN0aW9uKHByb2plY3Rpb24pO1xyXG5cclxuICAgIHZhciB6b29tID0gZDMuYmVoYXZpb3Iuem9vbSgpXHJcbiAgICAgICAgLnNjYWxlKHByb2plY3Rpb24uc2NhbGUoKSAqIDIgKiBNYXRoLlBJKVxyXG4gICAgICAgIC5zY2FsZUV4dGVudChbMSA8PCAyMCwgMSA8PCAyNV0pXHJcbiAgICAgICAgLnRyYW5zbGF0ZShwcm9qZWN0aW9uKFstNzEuMDc1MiwgNDIuMzM1XSkubWFwKGZ1bmN0aW9uKHgpIHsgcmV0dXJuIC14OyB9KSlcclxuICAgICAgICAub24oXCJ6b29tXCIsIHpvb21lZCk7XHJcblxyXG4gICAgdmFyIG1hcCA9IGQzLnNlbGVjdChjYW52YXMpXHJcbiAgICAgICAgLmF0dHIoXCJjbGFzc1wiLCBcIm1hcFwiKVxyXG4gICAgICAgIC5jYWxsKHpvb20pXHJcbiAgICAgICAgLm9uKFwibW91c2Vtb3ZlXCIsIG1vdXNlbW92ZWQpO1xyXG5cclxuICAgIHZhciBsYXllciA9IG1hcC5hcHBlbmQoXCJkaXZcIilcclxuICAgICAgICAuYXR0cihcImNsYXNzXCIsIFwibGF5ZXJcIik7XHJcblxyXG4gICAgdmFyIHJvdXRlR2VvID0ge3R5cGU6ICdMaW5lU3RyaW5nJywgY29vcmRpbmF0ZXM6IHRyaXBzWzBdLnRydWVfcGF0aH07XHJcbiAgICB2YXIgcm91dGUgPSBtYXAuYXBwZW5kKFwiZGl2XCIpXHJcbiAgICAgICAgLmF0dHIoXCJjbGFzc1wiLCBcInJvdXRlXCIpXHJcbiAgICAgICAgLmFwcGVuZCgnc3ZnJylcclxuICAgICAgICAuYXR0cignd2lkdGgnLCB3aWR0aCArICdweCcpXHJcbiAgICAgICAgLmF0dHIoJ2hlaWdodCcsIGhlaWdodCArICdweCcpXHJcbiAgICAgICAgLnNlbGVjdEFsbCgncGF0aCcpXHJcbiAgICAgICAgLmRhdGEoW3JvdXRlR2VvXSlcclxuICAgICAgICAuZW50ZXIoKVxyXG4gICAgICAgIC5hcHBlbmQoJ3BhdGgnKTtcclxuICAgIFxyXG4gICAgcm91dGVcclxuICAgICAgICAuYXR0cignY2xhc3MnLCAncm91dGUtcGF0aCcpXHJcbiAgICAgICAgLmF0dHIoJ2QnLCByb3V0ZVBhdGgpO1xyXG5cclxuICAgIHZhciBpbmZvID0gbWFwLmFwcGVuZChcImRpdlwiKVxyXG4gICAgICAgIC5hdHRyKFwiY2xhc3NcIiwgXCJjb29yZC1pbmZvXCIpO1xyXG5cclxuICAgIHpvb21lZCgpO1xyXG5cclxuICAgIGZ1bmN0aW9uIHpvb21lZCgpIHtcclxuICAgICAgdmFyIHRpbGVzID0gdGlsZVxyXG4gICAgICAgICAgLnNjYWxlKHpvb20uc2NhbGUoKSlcclxuICAgICAgICAgIC50cmFuc2xhdGUoem9vbS50cmFuc2xhdGUoKSlcclxuICAgICAgICAgICgpO1xyXG5cclxuICAgICAgcHJvamVjdGlvblxyXG4gICAgICAgICAgLnNjYWxlKHpvb20uc2NhbGUoKSAvIDIgLyBNYXRoLlBJKVxyXG4gICAgICAgICAgLnRyYW5zbGF0ZSh6b29tLnRyYW5zbGF0ZSgpKTtcclxuXHJcbiAgICAgIHJvdXRlLmF0dHIoJ2QnLCByb3V0ZVBhdGgpO1xyXG5cclxuICAgICAgdmFyIGltYWdlID0gbGF5ZXJcclxuICAgICAgICAgIC5zdHlsZShwcmVmaXggKyBcInRyYW5zZm9ybVwiLCBtYXRyaXgzZCh0aWxlcy5zY2FsZSwgdGlsZXMudHJhbnNsYXRlKSlcclxuICAgICAgICAuc2VsZWN0QWxsKFwiLnRpbGVcIilcclxuICAgICAgICAgIC5kYXRhKHRpbGVzLCBmdW5jdGlvbihkKSB7IHJldHVybiBkOyB9KTtcclxuXHJcbiAgICAgIGltYWdlLmV4aXQoKVxyXG4gICAgICAgICAgLmVhY2goZnVuY3Rpb24oZCkgeyB0aGlzLl94aHIuYWJvcnQoKTsgfSlcclxuICAgICAgICAgIC5yZW1vdmUoKTtcclxuXHJcbiAgICAgIGltYWdlLmVudGVyKCkuYXBwZW5kKFwic3ZnXCIpXHJcbiAgICAgICAgICAuYXR0cihcImNsYXNzXCIsIFwidGlsZVwiKVxyXG4gICAgICAgICAgLnN0eWxlKFwibGVmdFwiLCBmdW5jdGlvbihkKSB7IHJldHVybiBkWzBdICogMjU2ICsgXCJweFwiOyB9KVxyXG4gICAgICAgICAgLnN0eWxlKFwidG9wXCIsIGZ1bmN0aW9uKGQpIHsgcmV0dXJuIGRbMV0gKiAyNTYgKyBcInB4XCI7IH0pXHJcbiAgICAgICAgICAuZWFjaChmdW5jdGlvbihkKSB7XHJcbiAgICAgICAgICAgIHZhciBzdmcgPSBkMy5zZWxlY3QodGhpcyk7XHJcbiAgICAgICAgICAgIHRoaXMuX3hociA9IGQzLmpzb24oXCJodHRwOi8vXCIgKyBbXCJhXCIsIFwiYlwiLCBcImNcIl1bKGRbMF0gKiAzMSArIGRbMV0pICUgM10gKyBcIi50aWxlLm9wZW5zdHJlZXRtYXAudXMvdmVjdGlsZXMtaGlnaHJvYWQvXCIgKyBkWzJdICsgXCIvXCIgKyBkWzBdICsgXCIvXCIgKyBkWzFdICsgXCIuanNvblwiLCBmdW5jdGlvbihlcnJvciwganNvbikge1xyXG4gICAgICAgICAgICAgIHZhciBrID0gTWF0aC5wb3coMiwgZFsyXSkgKiAyNTY7IC8vIHNpemUgb2YgdGhlIHdvcmxkIGluIHBpeGVsc1xyXG5cclxuICAgICAgICAgICAgICB0aWxlUGF0aC5wcm9qZWN0aW9uKClcclxuICAgICAgICAgICAgICAgICAgLnRyYW5zbGF0ZShbayAvIDIgLSBkWzBdICogMjU2LCBrIC8gMiAtIGRbMV0gKiAyNTZdKSAvLyBbMO+/vSww77+9XSBpbiBwaXhlbHNcclxuICAgICAgICAgICAgICAgICAgLnNjYWxlKGsgLyAyIC8gTWF0aC5QSSk7XHJcblxyXG4gICAgICAgICAgICAgIHN2Zy5zZWxlY3RBbGwoXCJwYXRoXCIpXHJcbiAgICAgICAgICAgICAgICAgIC5kYXRhKGpzb24uZmVhdHVyZXMuc29ydChmdW5jdGlvbihhLCBiKSB7IHJldHVybiBhLnByb3BlcnRpZXMuc29ydF9rZXkgLSBiLnByb3BlcnRpZXMuc29ydF9rZXk7IH0pKVxyXG4gICAgICAgICAgICAgICAgLmVudGVyKCkuYXBwZW5kKFwicGF0aFwiKVxyXG4gICAgICAgICAgICAgICAgICAuYXR0cihcImNsYXNzXCIsIGZ1bmN0aW9uKGQpIHsgcmV0dXJuIGQucHJvcGVydGllcy5raW5kOyB9KVxyXG4gICAgICAgICAgICAgICAgICAuYXR0cihcImRcIiwgdGlsZVBhdGgpO1xyXG4gICAgICAgICAgICB9KTtcclxuICAgICAgICAgIH0pO1xyXG4gICAgfVxyXG5cclxuICAgIGZ1bmN0aW9uIG1vdXNlbW92ZWQoKSB7XHJcbiAgICAgIGluZm8udGV4dChmb3JtYXRMb2NhdGlvbihwcm9qZWN0aW9uLmludmVydChkMy5tb3VzZSh0aGlzKSksIHpvb20uc2NhbGUoKSkpO1xyXG4gICAgfVxyXG5cclxuICAgIGZ1bmN0aW9uIG1hdHJpeDNkKHNjYWxlLCB0cmFuc2xhdGUpIHtcclxuICAgICAgdmFyIGsgPSBzY2FsZSAvIDI1NiwgciA9IHNjYWxlICUgMSA/IE51bWJlciA6IE1hdGgucm91bmQ7XHJcbiAgICAgIHJldHVybiBcIm1hdHJpeDNkKFwiICsgW2ssIDAsIDAsIDAsIDAsIGssIDAsIDAsIDAsIDAsIGssIDAsIHIodHJhbnNsYXRlWzBdICogc2NhbGUpLCByKHRyYW5zbGF0ZVsxXSAqIHNjYWxlKSwgMCwgMSBdICsgXCIpXCI7XHJcbiAgICB9XHJcblxyXG4gICAgZnVuY3Rpb24gcHJlZml4TWF0Y2gocCkge1xyXG4gICAgICB2YXIgaSA9IC0xLCBuID0gcC5sZW5ndGgsIHMgPSBkb2N1bWVudC5ib2R5LnN0eWxlO1xyXG4gICAgICB3aGlsZSAoKytpIDwgbikgaWYgKHBbaV0gKyBcIlRyYW5zZm9ybVwiIGluIHMpIHJldHVybiBcIi1cIiArIHBbaV0udG9Mb3dlckNhc2UoKSArIFwiLVwiO1xyXG4gICAgICByZXR1cm4gXCJcIjtcclxuICAgIH1cclxuXHJcbiAgICBmdW5jdGlvbiBmb3JtYXRMb2NhdGlvbihwLCBrKSB7XHJcbiAgICAgIHZhciBmb3JtYXQgPSBkMy5mb3JtYXQoXCIuXCIgKyBNYXRoLmZsb29yKE1hdGgubG9nKGspIC8gMiAtIDIpICsgXCJmXCIpO1xyXG4gICAgICByZXR1cm4gKHBbMV0gPCAwID8gZm9ybWF0KC1wWzFdKSArIFwiZGVnIFNcIiA6IGZvcm1hdChwWzFdKSArIFwiZGVnIE5cIikgKyBcIiBcIlxyXG4gICAgICAgICAgICsgKHBbMF0gPCAwID8gZm9ybWF0KC1wWzBdKSArIFwiZGVnIFdcIiA6IGZvcm1hdChwWzBdKSArIFwiZGVnIEVcIik7XHJcbiAgICB9XHJcbn07XHJcbiIsIlxyXG5FQVJUSF9SQURJVVMgPSA2Mzc4ICMga21cclxuXHJcbmNsYXNzIGV4cG9ydHMuUGF0aFxyXG4gICAgY29uc3RydWN0b3I6IChwb2ludHMpIC0+XHJcbiAgICAgICAgbG9ucyA9IChwWzBdIGZvciBwIGluIHBvaW50cylcclxuICAgICAgICBsYXRzID0gKHBbMV0gZm9yIHAgaW4gcG9pbnRzKVxyXG4gICAgICAgIG1pbkxvbiA9IDAjTWF0aC5taW4uYXBwbHkgbnVsbCwgbG9uc1xyXG4gICAgICAgIG1pbkxhdCA9IDAjTWF0aC5taW4uYXBwbHkgbnVsbCwgbGF0c1xyXG5cclxuICAgICAgICBsb25TY2FsZSA9IEVBUlRIX1JBRElVUyoyKk1hdGguUEkvMzYwKk1hdGguY29zKG1pbkxhdCpNYXRoLlBJLzE4MClcclxuICAgICAgICBsYXRTY2FsZSA9IEVBUlRIX1JBRElVUyoyKk1hdGguUEkvMzYwXHJcblxyXG4gICAgICAgIEBwb2ludHMgPSAoWyhsb25zW2ldIC0gbWluTG9uKSpsb25TY2FsZSxcclxuICAgICAgICAgICAgICAgICAgICAobGF0c1tpXSAtIG1pbkxhdCkqbGF0U2NhbGVdIGZvciBpIGluIFswLi4ucG9pbnRzLmxlbmd0aF0pXHJcblxyXG4gICAgc3BlZWRzOiAodGltZXMpIC0+XHJcbiAgICAgICAgZm9yIGkgaW4gWzAuLi50aW1lcy5sZW5ndGgtMV1cclxuICAgICAgICAgICAgW3gwLCB5MF0gPSBAcG9pbnRzW2ldXHJcbiAgICAgICAgICAgIFt4MSwgeTFdID0gQHBvaW50c1tpKzFdXHJcbiAgICAgICAgICAgIGRpc3QgPSBNYXRoLnNxcnQoKHgxLXgwKSoqMiArICh5MS15MCkqKjIpXHJcblxyXG4gICAgICAgICAgICBkdCA9ICh0aW1lc1tpKzFdIC0gdGltZXNbaV0pLyg2MCo2MCkgIyBpbiBob3Vyc1xyXG4gICAgICAgICAgICBkaXN0L2R0XHJcblxyXG5cclxuXHJcbiIsIntQYXRofSA9IHJlcXVpcmUgJy4vcGF0aC5jb2ZmZWUnXHJcblxyXG5tYXJnaW4gPVxyXG4gICAgdG9wOiAyMFxyXG4gICAgcmlnaHQ6IDIwXHJcbiAgICBib3R0b206IDQwXHJcbiAgICBsZWZ0OiA1MFxyXG5cclxuZ3BzU3RkID0gMjAgIyBtZXRlcnNcclxuXHJcbmV4cG9ydHMuc2hvdyA9IChbe3RydWVfcGF0aH1dKSAtPlxyXG4gICAgZ3BzSW5wdXQgPSAkICcjZ3BzLXN0ZCdcclxuICAgIGdwc0lucHV0LnZhbCBncHNTdGRcclxuICAgIHVwZGF0ZSA9IC0+XHJcbiAgICAgICAgbmV3VmFsID0gK2dwc0lucHV0LnZhbCgpXHJcbiAgICAgICAgaWYgbm90IGlzTmFOKG5ld1ZhbCkgYW5kIG5ld1ZhbCA+IDBcclxuICAgICAgICAgICAgZ3BzU3RkID0gK2dwc0lucHV0LnZhbCgpXHJcbiAgICBncHNJbnB1dC5jaGFuZ2UgdXBkYXRlXHJcbiAgICBncHNJbnB1dC5rZXl1cCB1cGRhdGVcclxuXHJcbiAgICBwYXRoID0gbmV3IFBhdGggdHJ1ZV9wYXRoXHJcblxyXG4gICAgd2lkdGggPSAkKCcjcG9pbnQtbW9kZWwtY2FudmFzJykud2lkdGgoKSAtIG1hcmdpbi5sZWZ0IC0gbWFyZ2luLnJpZ2h0XHJcbiAgICBoZWlnaHQgPSAkKCcjcG9pbnQtbW9kZWwtY2FudmFzJykuaGVpZ2h0KCkgLSBtYXJnaW4udG9wIC0gbWFyZ2luLmJvdHRvbVxyXG5cclxuICAgIHhTY2FsZSA9IGQzLnNjYWxlLmxpbmVhcigpXHJcbiAgICAgICAgLnJhbmdlIFswLCB3aWR0aF1cclxuICAgICAgICAuZG9tYWluIGQzLmV4dGVudCAocFswXSBmb3IgcCBpbiBwYXRoLnBvaW50cy5jb25jYXQgcGF0aC5wb2ludHMpXHJcbiAgICB5U2NhbGUgPSBkMy5zY2FsZS5saW5lYXIoKVxyXG4gICAgICAgIC5yYW5nZSBbaGVpZ2h0LCAwXVxyXG4gICAgICAgIC5kb21haW4gZDMuZXh0ZW50IChwWzFdIGZvciBwIGluIHBhdGgucG9pbnRzLmNvbmNhdCBwYXRoLnBvaW50cylcclxuXHJcbiAgICBjYW52YXMgPSBkMy5zZWxlY3QgJyNwb2ludC1tb2RlbC1jYW52YXMnXHJcbiAgICAgICAgLmFwcGVuZCAnZydcclxuICAgICAgICAuYXR0ciAndHJhbnNmb3JtJywgXCJ0cmFuc2xhdGUoI3ttYXJnaW4ubGVmdH0sICN7bWFyZ2luLnJpZ2h0fSlcIlxyXG5cclxuICAgICMgY2F0Y2ggbW91c2UgZXZlbnRzXHJcbiAgICBjYW52YXMuYXBwZW5kICdyZWN0J1xyXG4gICAgICAgIC5hdHRyICd3aWR0aCcsIHdpZHRoXHJcbiAgICAgICAgLmF0dHIgJ2hlaWdodCcsIGhlaWdodFxyXG4gICAgICAgIC5zdHlsZSAnZmlsbCcsICcjRkZGRkZGJ1xyXG5cclxuICAgIGxpbmUgPSBkMy5zdmcubGluZSgpXHJcbiAgICAgICAgLnggKFt4LCB5XSkgLT4geFNjYWxlIHhcclxuICAgICAgICAueSAoW3gsIHldKSAtPiB5U2NhbGUgeVxyXG5cclxuICAgIHBhdGhQYXJ0cyA9IFtdXHJcbiAgICBkcyA9IDAuMDVcclxuICAgIHJlbWFpbmluZyA9IHBhdGgucG9pbnRzLnNsaWNlIDBcclxuICAgIGN1cnJlbnQgPSByZW1haW5pbmcuc2hpZnQoKVxyXG4gICAgd2hpbGUgcmVtYWluaW5nLmxlbmd0aCA+IDFcclxuICAgICAgICBuZXh0ID0gcmVtYWluaW5nWzBdXHJcbiAgICAgICAgZGVsdGEgPSAobmV4dFtpXSAtIGN1cnJlbnRbaV0gZm9yIGkgaW4gWzAsIDFdKVxyXG4gICAgICAgIGRlbHRhTGVuZ3RoID0gbGVuZ3RoID0gTWF0aC5zcXJ0KGRlbHRhWzBdKioyICsgZGVsdGFbMV0qKjIpXHJcbiAgICAgICAgd2hpbGUgbGVuZ3RoIDwgZHMgYW5kIHJlbWFpbmluZy5sZW5ndGggPiAxXHJcbiAgICAgICAgICAgIGN1cnJlbnQgPSByZW1haW5pbmcuc2hpZnQoKVxyXG4gICAgICAgICAgICBuZXh0ID0gcmVtYWluaW5nWzBdXHJcbiAgICAgICAgICAgIGRlbHRhID0gKG5leHRbaV0gLSBjdXJyZW50W2ldIGZvciBpIGluIFswLCAxXSlcclxuICAgICAgICAgICAgZGVsdGFMZW5ndGggPSBNYXRoLnNxcnQoZGVsdGFbMF0qKjIgKyBkZWx0YVsxXSoqMilcclxuICAgICAgICAgICAgbGVuZ3RoICs9IGRlbHRhTGVuZ3RoXHJcbiAgICAgICAgXHJcbiAgICAgICAgcCA9IChkcyAtIChsZW5ndGggLSBkZWx0YUxlbmd0aCkpL2RlbHRhTGVuZ3RoXHJcbiAgICAgICAgY3VycmVudCA9IFtjdXJyZW50WzBdK3AqZGVsdGFbMF0sIGN1cnJlbnRbMV0rcCpkZWx0YVsxXV1cclxuICAgICAgICBwYXRoUGFydHMucHVzaCBjdXJyZW50XHJcblxyXG4gICAgcGF0aFBhcnRzID0gZm9yIGkgaW4gWzAuLi5wYXRoUGFydHMubGVuZ3RoLTFdXHJcbiAgICAgICAgW3BhdGhQYXJ0c1tpXSwgcGF0aFBhcnRzW2krMV1dXHJcblxyXG4gICAgcGF0aHMgPSBjYW52YXMuc2VsZWN0QWxsICcucm91dGUtcGF0aCBtb2RlbCdcclxuICAgICAgICAuZGF0YSBwYXRoUGFydHNcclxuICAgIHBhdGhzLmV4aXQoKS5yZW1vdmUoKVxyXG4gICAgcGF0aHMuZW50ZXIoKVxyXG4gICAgICAgIC5hcHBlbmQgJ3BhdGgnXHJcbiAgICAgICAgLmF0dHIgJ2NsYXNzJywgJ3JvdXRlLXBhdGggbW9kZWwnXHJcbiAgICBwYXRocy5hdHRyICdkJywgbGluZVxyXG5cclxuICAgIGNvbG9yU2NhbGUgPSBkMy5zY2FsZS5saW5lYXIoKVxyXG4gICAgICAgIC5jbGFtcCB5ZXNcclxuICAgICAgICAuZG9tYWluIFstODAsIDBdXHJcbiAgICAgICAgLnJhbmdlIFtkMy5yZ2IoMHgyMiwgMHgyMiwgMHgyMiksIGQzLnJnYigweEZGLCAwLCAwKV1cclxuXHJcbiAgICBvbk1vdXNlID0gLT5cclxuICAgICAgICBbeCwgeV0gPSBkMy5tb3VzZSB0aGlzXHJcbiAgICAgICAgeCA9IHhTY2FsZS5pbnZlcnQgeFxyXG4gICAgICAgIHkgPSB5U2NhbGUuaW52ZXJ0IHlcclxuXHJcbiAgICAgICAgZ3BzU3F1YXJlZCA9IChncHNTdGQvMTAwMCkqKjJcclxuXHJcbiAgICAgICAgbWF4ID0gLTFlNTBcclxuICAgICAgICBwYXRocy5lYWNoIChbW3B4LCBweV1dKSAtPlxyXG4gICAgICAgICAgICBkaXN0U3F1YXJlZCA9ICh4LXB4KSoqMiArICh5LXB5KSoqMlxyXG4gICAgICAgICAgICBsb2dMaWtlID0gLTAuNSpkaXN0U3F1YXJlZC9ncHNTcXVhcmVkXHJcbiAgICAgICAgICAgIGlmIGxvZ0xpa2UgPiBtYXggdGhlbiBtYXggPSBsb2dMaWtlXHJcbiAgICAgICAgcGF0aHMuZWFjaCAoW1tweCwgcHldXSkgLT5cclxuICAgICAgICAgICAgZGlzdFNxdWFyZWQgPSAoeC1weCkqKjIgKyAoeS1weSkqKjJcclxuICAgICAgICAgICAgbG9nTGlrZSA9IC0wLjUqZGlzdFNxdWFyZWQvZ3BzU3F1YXJlZCAtIG1heFxyXG4gICAgICAgICAgICBkMy5zZWxlY3QodGhpcykuc3R5bGUgJ3N0cm9rZScsIGNvbG9yU2NhbGUgbG9nTGlrZVxyXG5cclxuICAgIGNhbnZhcy5vbiAnbW91c2Vtb3ZlJywgXy50aHJvdHRsZSBvbk1vdXNlLCA1MCxcclxuICAgICAgICBsZWFkaW5nOiB5ZXNcclxuICAgICAgICB0cmFpbGluZzogbm9cclxuIiwiXHJcbntQYXRofSA9IHJlcXVpcmUoJy4vcGF0aC5jb2ZmZWUnKVxyXG5cclxuZXhwb3J0cy5zaG93ID0gKHRyaXBzKSAtPlxyXG4gICAgZmlsbFRyaXBTZWxlY3QgdHJpcHMsIHNob3dUcmlwXHJcblxyXG5tYXJnaW4gPVxyXG4gICAgdG9wOiAyMFxyXG4gICAgcmlnaHQ6IDIwXHJcbiAgICBib3R0b206IDQwXHJcbiAgICBsZWZ0OiA1MFxyXG5cclxuc2hvd1RyaXAgPSAodHJpcCkgLT5cclxuICAgIHBhdGggPSBuZXcgUGF0aCB0cmlwLnBhdGhcclxuICAgIHRydWVQYXRoID0gbmV3IFBhdGggdHJpcC50cnVlX3BhdGhcclxuXHJcbiAgICBzaG93UGF0aHMgcGF0aCwgdHJ1ZVBhdGhcclxuICAgIHNob3dTcGVlZHMgdHJpcCwgcGF0aFxyXG5cclxucGF0aENhbnZhcyA9IG51bGxcclxuc2hvd1BhdGhzID0gKHBhdGgsIHRydWVQYXRoKSAtPlxyXG4gICAgd2lkdGggPSAkKCcjdHJpcC1wbG90LWNhbnZhcycpLndpZHRoKCkgLSBtYXJnaW4ubGVmdCAtIG1hcmdpbi5yaWdodFxyXG4gICAgaGVpZ2h0ID0gJCgnI3RyaXAtcGxvdC1jYW52YXMnKS5oZWlnaHQoKSAtIG1hcmdpbi50b3AgLSBtYXJnaW4uYm90dG9tXHJcblxyXG4gICAgeFNjYWxlID0gZDMuc2NhbGUubGluZWFyKClcclxuICAgICAgICAucmFuZ2UgWzAsIHdpZHRoXVxyXG4gICAgICAgIC5kb21haW4gZDMuZXh0ZW50IChwWzBdIGZvciBwIGluIHBhdGgucG9pbnRzLmNvbmNhdCB0cnVlUGF0aC5wb2ludHMpXHJcbiAgICB5U2NhbGUgPSBkMy5zY2FsZS5saW5lYXIoKVxyXG4gICAgICAgIC5yYW5nZSBbaGVpZ2h0LCAwXVxyXG4gICAgICAgIC5kb21haW4gZDMuZXh0ZW50IChwWzFdIGZvciBwIGluIHBhdGgucG9pbnRzLmNvbmNhdCB0cnVlUGF0aC5wb2ludHMpXHJcblxyXG4gICAgaWYgbm90IHBhdGhDYW52YXM/XHJcbiAgICAgICAgcGF0aENhbnZhcyA9IGQzLnNlbGVjdCAnI3RyaXAtcGxvdC1jYW52YXMnXHJcbiAgICAgICAgICAgIC5hcHBlbmQgJ2cnXHJcbiAgICAgICAgICAgIC5hdHRyICd0cmFuc2Zvcm0nLCBcInRyYW5zbGF0ZSgje21hcmdpbi5sZWZ0fSwgI3ttYXJnaW4ucmlnaHR9KVwiXHJcblxyXG4gICAgICAgIGxlZ2VuZCA9IHBhdGhDYW52YXMuYXBwZW5kICdnJ1xyXG4gICAgICAgICAgICAuYXR0ciAndHJhbnNmb3JtJywgXCJ0cmFuc2xhdGUoMCwgI3toZWlnaHR9KVwiXHJcbiAgICAgICAgbGVnZW5kLmFwcGVuZCAncmVjdCdcclxuICAgICAgICAgICAgLmF0dHIgJ2NsYXNzJywgJ3NjYWxlLWluZGljYXRvcidcclxuICAgICAgICAgICAgLmF0dHIgJ3gnLCAwXHJcbiAgICAgICAgICAgIC5hdHRyICd5JywgMFxyXG4gICAgICAgICAgICAuYXR0ciAnd2lkdGgnLCB4U2NhbGUoMSkgLSB4U2NhbGUoMClcclxuICAgICAgICAgICAgLmF0dHIgJ2hlaWdodCcsIDJcclxuICAgICAgICBsZWdlbmQuYXBwZW5kICd0ZXh0J1xyXG4gICAgICAgICAgICAuYXR0ciAnY2xhc3MnLCAnc2NhbGUtaW5kaWNhdG9yJ1xyXG4gICAgICAgICAgICAuYXR0ciAneCcsIDBcclxuICAgICAgICAgICAgLmF0dHIgJ3knLCAwXHJcbiAgICAgICAgICAgIC5hdHRyICdkeScsIDEyXHJcbiAgICAgICAgICAgIC50ZXh0ICcxIGttJ1xyXG5cclxuICAgIGxpbmUgPSBkMy5zdmcubGluZSgpXHJcbiAgICAgICAgLnggKFt4LCB5XSkgLT4geFNjYWxlIHhcclxuICAgICAgICAueSAoW3gsIHldKSAtPiB5U2NhbGUgeVxyXG5cclxuICAgIHRydWVTdmcgPSBwYXRoQ2FudmFzLnNlbGVjdEFsbCAnLnJvdXRlLXBhdGgnXHJcbiAgICAgICAgLmRhdGEgW3RydWVQYXRoLnBvaW50c11cclxuICAgIHRydWVTdmcuZXhpdCgpLnJlbW92ZSgpXHJcbiAgICB0cnVlU3ZnLmVudGVyKClcclxuICAgICAgICAuYXBwZW5kICdwYXRoJ1xyXG4gICAgICAgIC5hdHRyICdjbGFzcycsICdyb3V0ZS1wYXRoJ1xyXG4gICAgdHJ1ZVN2Zy5hdHRyICdkJywgbGluZVxyXG5cclxuICAgIHJlYWxTdmcgPSBwYXRoQ2FudmFzLnNlbGVjdEFsbCAnLnJvdXRlLXBhdGgtcmVhbC1kYXRhJ1xyXG4gICAgICAgIC5kYXRhIFtwYXRoLnBvaW50c11cclxuICAgIHJlYWxTdmcuZXhpdCgpLnJlbW92ZSgpXHJcbiAgICByZWFsU3ZnLmVudGVyKClcclxuICAgICAgICAuYXBwZW5kICdwYXRoJ1xyXG4gICAgICAgIC5hdHRyICdjbGFzcycsICdyb3V0ZS1wYXRoLXJlYWwtZGF0YSdcclxuICAgIHJlYWxTdmcuYXR0ciAnZCcsIGxpbmVcclxuXHJcbiAgICBjaXJjbGVzID0gcGF0aENhbnZhcy5zZWxlY3RBbGwgJy5yZWFsLWRhdGEtcG9pbnQnXHJcbiAgICAgICAgLmRhdGEgcGF0aC5wb2ludHNcclxuICAgIGNpcmNsZXMuZXhpdCgpLnJlbW92ZSgpXHJcbiAgICBjaXJjbGVzLmVudGVyKClcclxuICAgICAgICAuYXBwZW5kICdjaXJjbGUnXHJcbiAgICAgICAgLmF0dHIgJ2NsYXNzJywgJ3JlYWwtZGF0YS1wb2ludCdcclxuICAgICAgICAuYXR0ciAncicsIDNcclxuICAgIGNpcmNsZXNcclxuICAgICAgICAuYXR0ciAnY3gnLCAoW3gsIHldKSAtPiB4U2NhbGUgeFxyXG4gICAgICAgIC5hdHRyICdjeScsIChbeCwgeV0pIC0+IHlTY2FsZSB5XHJcblxyXG5zaG93U3BlZWRzID0gKHt0aW1lc30sIHBhdGgpIC0+XHJcbiAgICB3aWR0aCA9ICQoJyN0cmlwLXBsb3Qtc3BlZWQtY2FudmFzJykud2lkdGgoKSAtIG1hcmdpbi5sZWZ0IC0gbWFyZ2luLnJpZ2h0XHJcbiAgICBoZWlnaHQgPSAkKCcjdHJpcC1wbG90LXNwZWVkLWNhbnZhcycpLmhlaWdodCgpIC0gbWFyZ2luLnRvcCAtIG1hcmdpbi5ib3R0b21cclxuXHJcbiAgICBzcGVlZHMgPSBwYXRoLnNwZWVkcyB0aW1lc1xyXG4gICAgZGF0YSA9IChbdGltZXNbaV0sIHNwZWVkc1tpXV0gZm9yIGkgaW4gWzAuLi5zcGVlZHMubGVuZ3RoXSlcclxuXHJcbiAgICB4U2NhbGUgPSBkMy5zY2FsZS5saW5lYXIoKVxyXG4gICAgICAgIC5yYW5nZSBbMCwgd2lkdGhdXHJcbiAgICAgICAgLmRvbWFpbiBkMy5leHRlbnQgdGltZXNcclxuICAgIHlTY2FsZSA9IGQzLnNjYWxlLmxpbmVhcigpXHJcbiAgICAgICAgLnJhbmdlIFtoZWlnaHQsIDBdXHJcbiAgICAgICAgLmRvbWFpbiBbMCwgZDMubWF4IHNwZWVkc11cclxuXHJcbiAgICB4QXhpcyA9IGQzLnN2Zy5heGlzKClcclxuICAgICAgICAuc2NhbGUgeFNjYWxlXHJcbiAgICAgICAgLm9yaWVudCAnYm90dG9tJ1xyXG4gICAgeUF4aXMgPSBkMy5zdmcuYXhpcygpXHJcbiAgICAgICAgLnNjYWxlIHlTY2FsZVxyXG4gICAgICAgIC5vcmllbnQgJ2xlZnQnXHJcblxyXG4gICAgc3BlZWRDYW52YXMgPSBkMy5zZWxlY3QgJyN0cmlwLXBsb3Qtc3BlZWQtY2FudmFzJ1xyXG4gICAgc3BlZWRDYW52YXMuc2VsZWN0QWxsKCdnJykucmVtb3ZlKClcclxuXHJcbiAgICBzcGVlZENhbnZhcyA9IHNwZWVkQ2FudmFzXHJcbiAgICAgICAgLmFwcGVuZCAnZydcclxuICAgICAgICAuYXR0ciAndHJhbnNmb3JtJywgXCJ0cmFuc2xhdGUoI3ttYXJnaW4ubGVmdH0sICN7bWFyZ2luLnJpZ2h0fSlcIlxyXG5cclxuICAgIHNwZWVkQ2FudmFzLmFwcGVuZCAnZydcclxuICAgICAgICAuYXR0ciAnY2xhc3MnLCAneCBheGlzJ1xyXG4gICAgICAgIC5hdHRyICd0cmFuc2Zvcm0nLCBcInRyYW5zbGF0ZSgwLCAje2hlaWdodH0pXCJcclxuICAgICAgICAuY2FsbCB4QXhpc1xyXG4gICAgICAgIC5hcHBlbmQgJ3RleHQnXHJcbiAgICAgICAgICAgIC5hdHRyICd5JywgMjRcclxuICAgICAgICAgICAgLmF0dHIgJ2R5JywgJzAuNzFlbSdcclxuICAgICAgICAgICAgLmF0dHIgJ3gnLCB3aWR0aC8yXHJcbiAgICAgICAgICAgIC5zdHlsZSAndGV4dC1hbmNob3InLCAnbWlkZGxlJ1xyXG4gICAgICAgICAgICAudGV4dCAnVGltZSBbc10nXHJcblxyXG4gICAgc3BlZWRDYW52YXMuYXBwZW5kICdnJ1xyXG4gICAgICAgIC5hdHRyICdjbGFzcycsICd5IGF4aXMnXHJcbiAgICAgICAgLmNhbGwgeUF4aXNcclxuICAgICAgICAuYXBwZW5kICd0ZXh0J1xyXG4gICAgICAgICAgICAuYXR0ciAndHJhbnNmb3JtJywgJ3JvdGF0ZSgtOTApJ1xyXG4gICAgICAgICAgICAuYXR0ciAneScsIC0yNFxyXG4gICAgICAgICAgICAuYXR0ciAnZHknLCAnLTAuNzFlbSdcclxuICAgICAgICAgICAgLmF0dHIgJ3gnLCAtaGVpZ2h0LzJcclxuICAgICAgICAgICAgLnN0eWxlICd0ZXh0LWFuY2hvcicsICdtaWRkbGUnXHJcbiAgICAgICAgICAgIC50ZXh0ICdTcGVlZCBba3BoXSdcclxuXHJcbiAgICBsaW5lID0gZDMuc3ZnLmxpbmUoKVxyXG4gICAgICAgIC54IChbeCwgeV0pIC0+IHhTY2FsZSB4XHJcbiAgICAgICAgLnkgKFt4LCB5XSkgLT4geVNjYWxlIHlcclxuICAgIFxyXG4gICAgcGF0aCA9IHNwZWVkQ2FudmFzLnNlbGVjdEFsbCAnLnNwZWVkLXBhdGgnXHJcbiAgICAgICAgLmRhdGEgW2RhdGFdXHJcbiAgICBwYXRoLmV4aXQoKS5yZW1vdmUoKVxyXG4gICAgcGF0aC5lbnRlcigpXHJcbiAgICAgICAgLmFwcGVuZCAncGF0aCdcclxuICAgICAgICAuYXR0ciAnY2xhc3MnLCAnc3BlZWQtcGF0aCdcclxuICAgIHBhdGguYXR0ciAnZCcsIGxpbmVcclxuXHJcbmZpbGxUcmlwU2VsZWN0ID0gKHRyaXBzLCBvblNlbGVjdCkgLT5cclxuICAgIHNlbGVjdCA9ICQgJyN0cmlwLXNlbGVjdCdcclxuICAgIHNlbGVjdC5lbXB0eSgpXHJcbiAgICBmb3IgaSBpbiBbMC4uLnRyaXBzLmxlbmd0aF1cclxuICAgICAgICBzZWxlY3QuYXBwZW5kIFwiPG9wdGlvbiB2YWx1ZT1cXFwiI3tpfVxcXCI+I3tpfTwvb3B0aW9uPlwiXHJcbiAgICBzZWxlY3QuY2hhbmdlIC0+IG9uU2VsZWN0IHRyaXBzWytzZWxlY3QudmFsKCldXHJcbiAgICBvblNlbGVjdCB0cmlwc1swXVxyXG5cclxuIl19
