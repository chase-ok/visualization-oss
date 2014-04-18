
{mongoose} = db = require '../../db'
stops = require '../raw/stops'
stopTimes = require '../raw/stopTimes'
trips = require '../raw/trips'
tripFeeds = require '../raw/tripFeeds'
routes = require '../raw/routes'
utils = require '../../utils'
Q = require 'q'


exports.analyzeByStop = (prefix) ->
    StopDelay = exports.getStopDelayModel prefix

    StopTime = stopTimes.getModel prefix
    Stop = stops.getModel prefix
    Trip = trips.getModel prefix

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
            .then (delays) -> db.batchInsert StopDelay, delays, 2400

    TripUpdate = tripFeeds.getUpdateModel prefix

    findUpdates = ->
        getMatchingUpdates = (delay) ->
            agg = TripUpdate
                .aggregate()
                .match {tripId: delay.tripId, stopSequence: delay.sequence}
                .group {_id: "$start", delay: {$last: "$delay"}}
                .project {_id: 0, day: "$_id", delay: 1}
            Q.ninvoke agg, 'exec'

        processDelay = (delayObj) ->
            getMatchingUpdates delayObj
            .then (delays) ->
                return Q() unless delays.length > 0
                delayObj.delays = delays
                delayObj.saveQ()

        count = 0
        db.batchStream StopDelay.find().populate('trip'), 32, (delays) ->
            count += delays.length
            console.log count
            Q.all (processDelay delay for delay in delays)

    db.dropModel StopDelay
    .then createEmpties
    .then findUpdates

exports.getStopDelayModel = utils.memoizeUnary (prefix) ->
    schema = new mongoose.Schema
        stopId: {type: String, index: yes}
        tripId: {type: String, index: yes}
        routeId: {type: String, index: yes}
        sequence: Number
        scheduledTime: {type: Number, index: yes}
        delays: [{day: Date, delay: Number}]
    mongoose.model "#{prefix}StopDelay", schema


exports.analyzeByTrip = (prefix) ->
    TripDelay = exports.getTripDelayModel prefix
    StopDelay = exports.getStopDelayModel prefix
    TripUpdate = tripFeeds.getUpdateModel prefix
    Trip = trips.getModel prefix
    Stop = stops.getModel prefix

    db.dropModel TripDelay
    .then ->
        findStopDelaysByDay = (trip) ->
            agg = StopDelay.aggregate()
                .match {tripId: trip.tripId}
                .sort 'sequence'
                .unwind 'delays'
                .group
                    _id: '$delays.day'
                    delays: $push: 
                        sequence: '$sequence' 
                        delay: '$delays.delay'
                .project {day: '$_id', delays: 1, _id: 0}
                .sort 'day'
            Q.ninvoke agg, 'exec'

        findMeanStopDelays = (trip) ->
            agg = StopDelay.aggregate()
                .match {tripId: trip.tripId}
                .unwind 'delays'
                .group 
                    _id: '$sequence'
                    delay: {$avg: '$delays.delay'}
                .sort '_id'
                .project {sequence: '$_id', delay: 1, _id: 0}
            Q.ninvoke agg, 'exec'

        processTrip = (trip) ->
            Q.spread [findStopDelaysByDay(trip),
                      findMeanStopDelays(trip)],
            (byDay, mean) -> Q
                tripId: trip.tripId
                routeId: trip.routeId
                serviceId: trip.serviceId
                shapeId: trip.shapeId
                delaysByDay: byDay
                meanDelays: mean

        count = 0
        db.batchStream Trip.find(), 16, (trips) ->
            count += trips.length
            console.log count
            Q.all (processTrip trip for trip in trips)
            .then (delays) -> db.batchInsert TripDelay, delays, 20

exports.getTripDelayModel = utils.memoizeUnary (prefix) ->
    schema = new mongoose.Schema
        tripId: {type: String, index: yes}
        routeId: {type: String, index: yes}
        serviceId: String
        shapeId: String
        delaysByDay: [{day: Date, delays: [{sequence: Number, delay: Number}]}]
        meanDelays: [{sequence: Number, delay: Number}]
    mongoose.model "#{prefix}TripDelay", schema


exports.streamTripDelaySequences = (prefix) ->
    {EventEmitter} = require 'events'
    emitter = new EventEmitter()

    stream = exports.getTripDelayModel prefix
        .find({})
        .select('delaysByDay -_id')
        .stream()

    stream.on 'error', (error) -> emitter.emit 'error', error
    stream.on 'close', -> emitter.emit 'close'
    stream.on 'data', (tripDelay) ->
        for {delays} in tripDelay.delaysByDay
            emitter.emit 'data', delays

    emitter.pause = -> stream.pause()
    emitter.resume = -> stream.resume()

    emitter

exports.streamTripMeanDelaySequences = (prefix) ->
    {EventEmitter} = require 'events'
    emitter = new EventEmitter()

    stream = exports.getTripDelayModel prefix
        .find({})
        .select('meanDelays -_id')
        .stream()

    stream.on 'error', (error) -> emitter.emit 'error', error
    stream.on 'close', -> emitter.emit 'close'
    stream.on 'data', ({meanDelays}) -> 
        emitter.emit 'data', meanDelays if meanDelays.length > 0

    emitter.pause = -> stream.pause()
    emitter.resume = -> stream.resume()

    emitter

dumpDelaySequence = (stream, path) -> utils.defer (promise) ->
    fs = require 'fs'
    zlib = require 'zlib'

    output = fs.createWriteStream path

    stream.on 'error', (error) -> console.log error; promise.reject error
    stream.on 'close', -> output.end ']}', -> promise.resolve()

    output.write '{"sequences":['
    first = yes
    stream.on 'data', (delays) ->
        if first then first = no
        else output.write ','

        points = ([sequence, delay] for {sequence, delay} in delays)
        output.write JSON.stringify points
        #if not output.write JSON.stringify points
        #    stream.pause()
        #    output.once 'drain', -> stream.resume()

exports.dumpTripDelaySequences = (prefix, path) -> 
    sequences = exports.streamTripDelaySequences prefix
    dumpDelaySequence sequences, path

exports.dumpTripMeanDelaySequences = (prefix, path) -> 
    sequences = exports.streamTripMeanDelaySequences prefix
    dumpDelaySequence sequences, path

exports.dumpStopDelays = (prefix, path, start=(12+5)*60*60, duration=30*60) ->
    end = start + duration
    Stop = stops.getModel prefix
    fs = require 'fs'

    query = exports.getStopDelayModel prefix
        .aggregate()
        .match 
            scheduledTime:
                $gte: start
                $lte: end
        .unwind 'delays'
        .group
            _id: '$stopId'
            meanDelay: $avg: '$delays.delay'
        .project
            stopId: '$_id'
            meanDelay: 1
            _id: 0
    Q.ninvoke query, 'exec'
    .then (delays) ->
        queries = []
        for delay in delays
            queries.push(Stop
                .findOne {stopId: delay.stopId}
                .select 'lat lon -_id'
                .execQ())

        Q.all queries
        .then (stops) ->
            data = []
            for stop, i in stops
                data.push
                    delay: delays[i].meanDelay
                    lat: stop.lat
                    lon: stop.lon
            Q data
    .then (data) ->
        fs.writeFileSync path, JSON.stringify
            delays: data


if require.main is module
    ###db.connect()
    .then -> console.log 'connected'
    .then -> exports.analyzeByStop 'Mbta'
    .then -> exports.analyzeByTrip 'Mbta'
    .done -> process.exit()
    ###

    # TODO: have to memoize the results of get model

    ###
    dir = 'public/data/gtfs/analysis'
    db.connect()
    .then -> 
        path = "#{dir}/mbta-trip-sequences.json"
        exports.dumpTripDelaySequences 'Mbta', path
    #.then ->
    #    path = "#{dir}/mbta-mean-trip-sequences.json"
    #    exports.dumpTripMeanDelaySequences 'Mbta', path
    .done -> process.exit()
    ###

    dir = 'public/data/gtfs/analysis'
    db.connect()
    .then ->
        path = "#{dir}/mbta-stop-delays-1700-1800.json"
        exports.dumpStopDelays 'Mbta', path, (12+5)*60*60, 60*60
    .done ->
        console.log 'done'
        process.exit()

