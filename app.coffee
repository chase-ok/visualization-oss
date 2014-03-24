
express = require 'express'
http = require 'http'
path = require 'path'
db = require './data/db'

app = express()
app.set 'port', process.env.PORT or 5000
app.set 'views', __dirname + '/views'
app.set 'view engine', 'jade'

middleware = [express.favicon(),
              express.logger('dev'),
              express.bodyParser(),
              express.methodOverride(),
              app.router,
              express.static(path.join __dirname, 'public')]
if app.get('env') is 'development'
  middleware.push express.errorHandler()
app.use ware for ware in middleware

require('./routes').create app

http.createServer(app).listen app.get('port'), ->
    console.log "Express server listening on port #{app.get 'port'}"
    db.connect().done -> console.log 'Connected to database'