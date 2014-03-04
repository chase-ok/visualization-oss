fs = require 'fs'
{mongoose} = db = require '../db'
csv = require 'csv'
utils = require './utils'
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
    model = mongoose.model "#{prefix}Shape", schema
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

if require.main is module
    db.connect()
    .then -> exports.load 'Mbta', utils.mbtaDir
    .done -> process.exit()