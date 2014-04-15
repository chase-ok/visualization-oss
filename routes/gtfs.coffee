
shapes = require '../data/gtfs/raw/shapes'
routes = require '../data/gtfs/raw/routes'
trips = require '../data/gtfs/raw/trips'
delays = require '../data/gtfs/analysis/delays'
{succeed, fail} = utils = require './utils'

checkAgency = (req) ->
    agency = req.params.agency.toLowerCase()
    if agency in ['mbta']
        agency
    else
        fail res, "Unknown agency #{agency}"
        false

getRoutes = (req, res) ->
    return unless agency = checkAgency req
    routes.getModel(agency).findQ()
    .catch (error) -> fail res, error
    .done (routes) -> succeed res, {routes}

getTrips = (req, res) ->
    return unless agency = checkAgency req

    find = {}
    find.routeId = req.query.route if req.query.route?

    trips.getModel(agency).find find
        .limit parseInt(req.query.limit) or 1024
        .execQ()
    .catch (error) -> fail res, error
    .done (trips) -> succeed res, {trips}

getShapes = (req, res) ->
    return unless agency = checkAgency req

    find = {}
    find.routeId = req.query.route if req.query.route?
    find.tripId = req.query.trip if req.query.trip?

    shapes.getModel(agency).find find
        .limit parseInt(req.query.limit) or 1024
        .execQ()
    .catch (error) -> fail res, error
    .done (shapes) -> succeed res, {shapes}

exports.create = (app) ->
    app.get '/gtfs', (req, res) -> res.render 'gtfs'
    app.get '/gtfs/:agency/routes', getRoutes
    app.get '/gtfs/:agency/trips', getTrips
    app.get '/gtfs/:agency/shapes', getShapes
    app.get '/gtfs-map', (req, res) -> res.render 'gtfs-map'
    app.get '/gtfs-routes-map', (req, res) -> res.render 'gtfs-routes-map'
