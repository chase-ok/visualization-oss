
from numpy import *
from matplotlib.pyplot import *
from collections import namedtuple

import paths as pth
import trips
from trips import SEC, METER, KM, KPH

Parameter = namedtuple('Parameter', 'default min max')

parameters = {
    'speed': Parameter(30*KPH, 0.1*KPH, 80*KPH),
    'duty': Parameter(1, 0, 1),
    'duty_cycle': Parameter(120*SEC, 10*SEC, 10*60*SEC),
    'position_std': Parameter(15*METER, 0.01*METER, 500*METER),
    'sample_time': Parameter(30*SEC, 1*SEC, 30*60*SEC),
    'sample_scale': Parameter(5*SEC, 0.1*SEC, 30*SEC)
}

def default_param_values():
    return dict((key, param.default) for key, param in parameters.iteritems())

complicated_path = pth.single_segment_path(0.5*KM)
complicated_path += pth.corner_path(1.0*KM)
complicated_path += pth.single_segment_path(0.5*KM)
complicated_path += pth.single_segment_path(0.5*KM, pi/2)
complicated_path += pth.single_segment_path(0.5*KM, pi/4)
complicated_path += pth.single_segment_path(1.0*KM, -pi/2)

paths = {
    'simple': pth.single_segment_path(4*KM),
    'corner': pth.corner_path(4*KM),
    'complicated': complicated_path
}

def generate_trip(param_values, path):
    speed_distr = trips.duty_cycle_speed(param_values['speed'], 
                                         param_values['duty_cycle'], 
                                         param_values['duty'])

    position_error = \
            trips.gaussian_position_error(param_values['position_std'])
            

    sample_time = trips.exponential_sample_time(param_values['sample_time'],
                                                param_values['sample_scale'])

    bus = trips.Vehicle(speed_distr, position_error)
    return bus.drive_path(path, sample_time)


def normal_pdf(mean, std, x):
    return 1./(std*sqrt(2*pi))*exp(-(x-mean)**2/(2*std**2))

def normal_log_pdf(mean, std, x):
    return -0.5*((x-mean)/std)**2 - log(std*sqrt(2*pi))

class SimpleModel(object):

    def __init__(self, param_values):
        self.param_values = param_values
        self.mean_speed = param_values['speed']*param_values['duty']
        self.pos_std = param_values['position_std']

    def log_likelihood(self, trip):
        likelihood = 0.0
        for i, time in enumerate(trip.times):
            expected_length = min(trip.true_path.length-1*METER, 
                                  time*self.mean_speed)
            expected_pos = trip.true_path.position(expected_length)

            pos = trip.path.points[i]
            dist = pos - expected_pos
            likelihood += normal_log_pdf(0, self.pos_std, dist).sum()
        return likelihood

def bayes_update(priors, models, trip):
    for i, model in enumerate(models):
        priors.flat[i] += model.log_likelihood(trip)
    priors -= priors.max()

def exp_priors(log_priors):
    priors = exp(log_priors)
    return priors/priors.sum()

def create_suite(model_class, param_ranges):
    shape = tuple(len(values) for _, values in param_ranges)
    priors = zeros(shape, float)

    models = []
    for indices in ndindex(*shape):
        model_param_values = default_param_values()
        for (param, values), index in zip(param_ranges, indices):
            model_param_values[param] = values[index]
        models.append(model_class(model_param_values))

    return param_ranges, priors, models

if __name__ == '__main__':
    param_ranges, priors, models = create_suite(SimpleModel, [
        ('speed', linspace(5*KPH, 40*KPH, 80)),
        ('position_std', linspace(1*METER, 100*METER, 40))
    ])
    
    param_values = default_param_values()
    param_values['speed'] = 30*KPH
    param_values['duty'] = 0.8
    param_values['position_std'] = 30*METER
    print param_values

    for i in range(5):
        print i
        trip = generate_trip(param_values, paths['complicated'])
        bayes_update(priors, models, trip)

    posteriors = exp_priors(priors)

    std, speed = meshgrid(param_ranges[1][1], param_ranges[0][1])
    pcolor(speed/KPH, std/METER, posteriors)
    hold(True)
    plot(param_values['speed']*param_values['duty']/KPH, 
         param_values['position_std']/METER, 'kx', ms=10)
    xlabel('Speed [kph]')
    ylabel('Position std. [m]')
    colorbar()
    show()


