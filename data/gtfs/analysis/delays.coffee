
{mongoose} = db = require '../../db'
stops = require '../raw/stops'
stopTimes = require '../raw/stopTimes'
trips = require '../raw/trips'
tripFeeds = require '../raw/tripFeeds'
routes = require '../raw/routes'
utils = require './utils'
Q = require 'q'


exports.analyze = (prefix) ->
    schema = new mongoose.Schema
        #stop: utils.makeRef "#{prefix}Stop"
        #trip: utils.makeRef "#{prefix}Trip"
        #route: utils.makeRef "#{prefix}Route"
        stopId: {type: String, index: yes}
        tripId: {type: String, index: yes}
        routeId: {type: String, index: yes}
        sequence: Number
        scheduledTime: Number
        delays: [Number]
    Delay = mongoose.model "#{prefix}Delay", schema

    StopTime = stopTimes.getModel prefix
    Stop = stops.getModel prefix
    Trip = trips.getModel prefix
    Route = routes.getModel prefix

    createEmpties = ->
        findRoute = (time) ->
            query = Trip.findOne {tripId: time.tripId}
                        .select 'routeId'
            Q.ninvoke query, 'exec'
            .then (trip) -> Q {time, routeId: trip.routeId}

        createDelay = ({time, routeId}) -> Q
            stopId: time.stopId
            tripId: time.tripId
            routeId: routeId
            sequence: time.sequence
            scheduledTime: time.arrival
            delays: []

        processTime = (time) ->
            findRoute time
            .then createDelay

        count = 0
        db.batchStream StopTime.find(), 2048, (times) ->
            count += times.length
            console.log count
            Q.all (processTime time for time in times)
            .then (delays) -> db.batchInsert Delay, delays, 2400

    TripUpdate = tripFeeds.getUpdateModel prefix

    findUpdates = ->
        getMatchingUpdates = (delay) ->
            agg = TripUpdate
                .aggregate()
                .match {tripId: delay.tripId, stopSequence: delay.sequence}
                .group {_id: "$start", delay: {$last: "$delay"}}
            Q.ninvoke agg, 'exec'

        processDelay = (delayObj) ->
            getMatchingUpdates delayObj
            .catch (err) -> console.log err
            .then (updates) ->
                return Q() unless updates.length > 0
                console.log updates.length, delayObj.delays
                delayObj.delays = (update.delay for update in updates)
                delayObj.saveQ()

        count = 0
        db.batchStream Delay.find().populate('trip'), 64, (delays) ->
            count += delays.length
            console.log count
            Q.all (processDelay delay for delay in delays)


    #db.dropModel Delay
    #.then createEmpties
    Q()
    .then findUpdates
    .done()

if require.main is module
    db.connect()
    .then -> console.log 'connected'
    .then -> exports.analyze 'Mbta'
    #.done -> process.exit()