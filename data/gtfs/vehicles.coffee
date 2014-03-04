{mongoose} = db = require '../db'
utils = require './utils'
Q = require 'Q'
http = require 'q-io/http'
http2 = require 'http'


exports.updateSchema = updateSchema = new mongoose.Schema
    vehicleId: String
    tripId: String
    start: Date
    scheduleRelationship: Number
    lat: Number
    lon: Number
    stopSequence: Number
    timestamp: Date


readUpdateStream = (model, url) ->
    http.read url
    .then (response) ->
        proto = utils.getRealtimeProto 'FeedMessage'
        updates = parseUpdateMessage proto.decode response
        db.batchInsert model, updates
        console.log "Streamed #{updates.length} updates."
    .fail (err) -> 
        console.log err
        process.exit()

parseUpdateMessage = (message) ->
    {header, entity} = message
    parseUpdate(x) for x in entity

parseUpdate = ({id, vehicle}) ->
    vehicleId: id
    tripId: vehicle.trip?.trip_id
    start: utils.parseDateString vehicle.trip?.start_date
    scheduleRelationship: vehicle.trip?.schedule_relationship
    lat: vehicle.position?.latitude
    lon: vehicle.position?.longitude
    stopSequence: vehicle.current_stop_sequence
    timestamp: 
        if vehicle.timestamp? then new Date vehicle.timestamp.toNumber()*1000
        else null

exports.pollUpdateStream = (prefix, url, interval=30*1000) ->
    model = mongoose.model "#{prefix}VehicleUpdate", updateSchema
    poll = -> readUpdateStream model, url
    setInterval poll, interval


if require.main is module
    db.connect()
    .then -> exports.pollUpdateStream 'Mbta', 
             'http://developer.mbta.com/lib/gtrtfs/Vehicles.pb'