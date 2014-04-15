fs = require 'fs'
{mongoose} = db = require '../../db'
csv = require 'csv'
utils = require './utils'
{memoizeUnary} = require '../../utils'
Q = require 'Q'
_ = require 'underscore'

exports.schema = schema = new mongoose.Schema
    shapeId: String
    points: [{
        lat: Number
        lon: Number
        sequence: Number
        distTraveled: Number
    }]

schema.index {shapeId: 1}, {unique: yes}

exports.load = (prefix, baseDir) ->
    model = exports.getModel prefix
    db.dropModel model
    .then -> parseCsvFile model, "#{baseDir}/shapes.txt"

parseCsvFile = (model, file) ->
    deferred = Q.defer()

    csv().from.stream(fs.createReadStream(file), {columns: yes})
    .transform parseRow
    .on 'error', (err) -> deferred.reject err
    .to.array (points) ->
        console.log 'grouping'
        shapes = groupIntoShapes points
        console.log shapes.length
        db.batchInsert model, shapes, 128
        .then -> deferred.resolve()

    deferred.promise

parseRow = (row) ->
    shapeId: row.shape_id
    lat: parseFloat row.shape_pt_lat
    lon: parseFloat row.shape_pt_lon
    sequence: parseInt row.shape_pt_sequence
    distTraveled: parseInt(row.shape_dist_traveled) or null

groupIntoShapes = (points) ->
    shapes = {}
    for point, i in points
        if point.shapeId not of shapes
            shapes[point.shapeId] =
                shapeId: point.shapeId
                points: [_.omit point, 'shapeId']
        else
            shapes[point.shapeId].points.push(_.omit point, 'shapeId')
    _.values shapes
 
exports.getModel = memoizeUnary (prefix) ->
    mongoose.model "#{prefix}Shape", schema

exports.dumpTopoJSON = (prefix, path) ->
    Shape = exports.getModel prefix
    Trip = require('./trips').getModel prefix
    Route = require('./routes').getModel prefix

    geo =
        type: 'FeatureCollection'
        features: []

    processShape = (shape) ->
        Trip.findOneQ {shapeId: shape.shapeId}
        .then (trip) ->
            if trip
                Route.findOneQ {routeId: trip.routeId}
            else
                Q null
        .then (route) ->
            geo.features.push
                type: 'Feature'
                properties:
                    id: shape.shapeId
                    color: route?.color
                    name: route?.longName or route?.shortName
                geometry:
                    type: 'LineString'
                    coordinates: ([p.lon, p.lat] for p in shape.points)
            Q()

    db.batchStream Shape.find(), 256, (shapes) ->
        Q.all (processShape shape for shape in shapes)
    .catch console.error
    .then ->
        topojson = require 'topojson'
        topo = topojson.topology {shapes: geo},
            'property-transform': (props, key, value) ->
                props[key] = value
                yes # copy all of the properties

        fs.writeFileSync path, JSON.stringify topo
        Q()

if require.main is module
    db.connect()
    #.then -> exports.load 'Mbta', utils.mbtaDir
    .then -> exports.dumpTopoJSON 'Mbta', 'public/data/geo/mbta-shapes.topojson'
    .done -> process.exit()
