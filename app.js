// Generated by CoffeeScript 1.6.3
var app, express, http, middleware, path, ware, _i, _len;

express = require('express');

http = require('http');

path = require('path');

app = express();

app.set('port', process.env.PORT || 5000);

app.set('views', __dirname + '/views');

app.set('view engine', 'jade');

middleware = [express.favicon(), express.logger('dev'), express.bodyParser(), express.methodOverride(), app.router, express["static"](path.join(__dirname, 'public'))];

if (app.get('env') === 'development') {
  middleware.push(express.errorHandler());
}

for (_i = 0, _len = middleware.length; _i < _len; _i++) {
  ware = middleware[_i];
  app.use(ware);
}

app.get('/networks', function(req, res) {
  return res.render('networks');
});

http.createServer(app).listen(app.get('port'), function() {
  return console.log("Express server listening on port " + (app.get('port')));
});
