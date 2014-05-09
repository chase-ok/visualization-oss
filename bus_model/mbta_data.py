
from pymongo import MongoClient
client = MongoClient()
db = client['visualization-oss']

from paths import Path, path_from_lon_lat
from trips import Trip
from numpy import *
from matplotlib.pyplot import *

route8_query = dict(routeId='08',
                    headsign='Kenmore Station via South Bay Center & Ruggles Station')

def find_trip_ids(query=route8_query):
    return list(db.mbtatrips.find(query).distinct('tripId'))

def find_shape(query=route8_query):
    id = db.mbtatrips.find(query).distinct('shapeId')[0]
    return db.mbtashapes.find_one({'shapeId': id})

def shape_to_path(shape):
    points = array([[p['lon'], p['lat']] for p in shape['points']]) 
    return path_from_lon_lat(points)

def show_path():
    path = shape_to_path(find_shape())
    path.plot()
    show()

def find_real_trips(query=route8_query, min_points=10, 
                    trip_separation_threshold=30*60):
    trip_ids = find_trip_ids(query)

    agg = db.mbtavehicleupdates.aggregate([
        {'$match': {'tripId': {'$in': list(trip_ids)}}},
        {'$group': {
            '_id': {'vehicleId': '$vehicleId', 'start': '$start'},
            'points': {'$push': { 
                'lat': '$lat',
                'lon': '$lon',
                'time': '$timestamp'}}}},
        {'$unwind': '$points'},
        {'$sort': {'points.time': 1}},
        {'$group': {
            '_id': '$_id',
            'lats': {'$push': '$points.lat'},
            'lons': {'$push': '$points.lon'},
            'times': {'$push': '$points.time'}}}])
    
    trips = []
    for trip in agg['result']:
        trip_times = [(t - trip['times'][0]).total_seconds() 
                      for t in trip['times']]
        if len(trip_times) < min_points: continue

        lon_lats = []
        times = []

        for time, lon, lat in zip(trip_times, trip['lons'], trip['lats']):
            if times and times[-1] == time: continue
            
            if times and time - times[-1] > trip_separation_threshold:
                trips.append(Trip(array(times), 
                                  path_from_lon_lat(array(lon_lats))))
                lon_lats = []
                times = []

            lon_lats.append([lon, lat])
            times.append(time)

        if times:
            trips.append(Trip(array(times), 
                              path_from_lon_lat(array(lon_lats))))

    return trips

def create_trip_sample(query=route8_query):
    true_path = shape_to_path(find_shape(query))

    trips = find_real_trips(query)
    for trip in trips:
        trip.true_path = true_path

    return trips

def show_sample():
    trips = create_trip_sample()
    longest = max(trips, key=lambda t: len(t.times))
    
    longest.true_path.plot('k-'); hold(True)
    longest.path.plot('rx')
    axis('equal')
    show()

    longest.plot_naive_speeds()
    show()

