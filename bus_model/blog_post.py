
from numpy import *
from matplotlib.pyplot import *

import mbta_data
trips = mbta_data.create_trip_sample()
path = trips[0].true_path

if True:
    subplot(211)
    path.plot('k-')
    hold(True)
    trips[0].path.plot('rx')
    xlabel('km')
    ylabel('km')
    axis('equal')

    subplot(212)
    trips[0].plot_naive_speeds()
    xlabel('Time [s]')
    ylabel('Speed [kph]')
    show()


import point_model
if False:
    point_model.show_velocity_like(trips[31])
if False:
    point_model.show_param_estimates(trips[31])
if True:
    for trip in trips:
        params = point_model.estimate_params(trip)
        print params['mean'], params['std']
    

