
from numpy import *
from matplotlib.pyplot import *

import mbta_data
#sample = mbta_data.create_trip_sample()
#mbta_data.show_sample()
mbta_data.dump_trip_sample('web/trips.json')

import point_model
#point_model.show_param_estimates(sample[1])


