{mongoose} = db = require '../../db'
utils = require './utils'
Q = require 'Q'
http = require 'q-io/http'
http2 = require 'http'


exports.updateSchema = updateSchema = new mongoose.Schema
    tripId:
        type: String
        index: yes
    start:
        type: Date
        index: yes
    scheduleRelationship: Number
    stopSequence: Number
    delay:
        type: Number
        index: yes
updateSchema.index {tripId: 1, stopSequence: 1}

lastUpdate = 0
readUpdateStream = (model, url) ->
    http.read url
    .then (response) ->
        proto = utils.getRealtimeProto 'FeedMessage'
        {time, updates} = parseUpdateMessage proto.decode response
        if time > lastUpdate
            lastUpdate = time
            db.batchInsert model, updates
            .then -> console.log "Streamed #{updates.length} updates."
        else
            console.log 'No updates'
    .fail (err) -> 
        console.log err

parseUpdateMessage = (message) ->
    {header, entity} = message
    time: header.timestamp.toNumber()
    updates: parseUpdate(x) for x in entity

parseUpdate = ({id, trip_update}) ->
    stopTime = trip_update.stop_time_update[0]
    if trip_update.stop_time_update.length > 1
        console.warn 'MULTIPLE STOP UPDATES!'
        console.warn trip_update

    tripId: id
    start: utils.parseDateString trip_update.trip?.start_date
    scheduleRelationship: trip_update.trip?.schedule_relationship
    stopSequence: stopTime?.stop_sequence
    delay: stopTime?.arrival?.delay

exports.pollUpdateStream = (prefix, url, interval=30*1000) ->
    model = exports.getUpdateModel prefix
    poll = -> readUpdateStream model, url
    setInterval poll, interval

exports.getUpdateModel = (prefix) -> 
    mongoose.model "#{prefix}TripUpdate", updateSchema

if require.main is module
    db.connect()
    .then -> exports.pollUpdateStream 'Mbta', 
             'http://developer.mbta.com/lib/gtrtfs/Passages.pb'