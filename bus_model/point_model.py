
from numpy import *
from matplotlib.pyplot import *

DX = 0.01

def discretize_path(path):
    points = []
    for dist in linspace(0, 0.999*path.length, ceil(path.length/DX)):
        points.append(path.position(dist))
    return array(points)

GPS_STD = 0.08

def point_log_likelihood(trip, discrete_path):
    like = empty((len(trip), discrete_path.shape[0]), float)
    for i in range(len(trip)):
        dist_squared = sum((discrete_path - trip.path.points[newaxis, i])**2,
                           axis=1)
        like[i] = -0.5*dist_squared/GPS_STD**2
        like[i] -= like[i].max()
    return like

HOUR = 60.*60
MAX_VEL = 70./HOUR
DVEL = 1./HOUR
VELOCITIES = linspace(0, MAX_VEL, MAX_VEL/DVEL)

def velocity_log_likelihood(trip, discrete_path, point_like, 
                            like_cutoff=-100):
    like = empty((len(trip)-1, len(VELOCITIES)), float)

    for i, (t1, t2) in enumerate(zip(trip.times, trip.times[1:])):
        dt = t2 - t1

        for j, velocity in enumerate(VELOCITIES):
            shift = int(round(velocity*dt/DX))
            if shift == 0:
                joint = point_like[i+1] + point_like[i]
            else:
                joint = point_like[i+1, shift:] + point_like[i, :-shift]

            joint = joint[joint > like_cutoff]
            if joint.size > 0:
                like[i, j] = max(like_cutoff, logaddexp.reduce(joint))
            else:
                like[i, j] = like_cutoff
        like[i] -= like[i].max()

    return like


def velocity_log_pdf(mean=20/HOUR, std=15/HOUR,
                     uniform=0.05):
    x = VELOCITIES
    normal = exp(-(x-mean)**2/(2*std**2))
    mixture = normal + uniform
    return log(mixture/mixture.sum())

def velocity_log_pdf_old(slow_mean=8/HOUR, slow_std=15/HOUR,
                 fast_mean=40/HOUR, fast_std=10/HOUR,
                 ratio=0.5, uniform=0.02):
    x = VELOCITIES
    slow = ratio*exp(-(x-slow_mean)**2/(2*slow_std**2))
    fast = (1-ratio)*exp(-(x-fast_mean)**2/(2*fast_std**2))
    mixture = slow + fast + uniform
    return log(mixture/mixture.sum())

def match_velocity_pdf(log_pdf, velocity_like):
    log_prob = 0.0
    for i in range(velocity_like.shape[0]):
        joint = log_pdf + velocity_like[i, :]
        log_prob += logaddexp.reduce(joint)
    return log_prob

def show_velocity_like(trip):
    true_path = trip.true_path
    discrete_path = discretize_path(true_path)
    point_like = point_log_likelihood(trip, discrete_path)
    velocity_like = velocity_log_likelihood(trip, discrete_path, point_like)

    times, speeds = meshgrid(trip.times, VELOCITIES)
    pcolor(times, speeds*HOUR, exp(velocity_like).T)
    xlabel('Time [s]')
    ylabel('Speed [kph]')
    xlim([times.min(), times.max()])
    show()

    combined = empty(velocity_like.shape[1], float)
    for i in range(combined.size):
        combined[i] = logaddexp.reduce(velocity_like[:, i])
    combined -= combined.max()
    plot(VELOCITIES*HOUR, exp(combined)/exp(combined).sum(), label='Combined Data')
    hold(True)

    log_pdf = velocity_log_pdf(mean=10/HOUR, std=18/HOUR)
    plot(VELOCITIES*HOUR, exp(log_pdf), label='Model')

    xlabel('Speed [kph]')
    ylabel('PDF')
    legend()
    
    show()


def bayes_update(priors, velocity_log_pdfs, trips):
    for trip in trips:
        discrete = discretize_path(trip.true_path)
        point_like = point_log_likelihood(trip, discrete)
        velocity_like = velocity_log_likelihood(trip, discrete, point_like)

        for i, log_pdf in enumerate(velocity_log_pdfs):
            priors.flat[i] += match_velocity_pdf(log_pdf, velocity_like)
        priors -= priors.max()

    return priors
            
def create_suite(*param_ranges):
    shape = tuple(len(values) for _, values in param_ranges)
    priors = zeros(shape, float)

    models = []
    for indices in ndindex(*shape):
        model_param_values = dict()
        for (param, values), index in zip(param_ranges, indices):
            model_param_values[param] = values[index]
        models.append(velocity_log_pdf(**model_param_values))

    return param_ranges, priors, models

def estimate_params(trip):
    param_ranges, priors, models = create_suite(
            ('mean', linspace(1/HOUR, 40/HOUR)),
            ('std', linspace(1/HOUR, 40/HOUR)))

    bayes_update(priors, models, [trip])

    max_index = unravel_index(priors.argmax(), priors.shape)
    return dict((p[0], p[1][i]*HOUR) for p, i in zip(param_ranges, max_index))

def show_param_estimates(trip):
    show_velocity_like(trip)

    param_ranges, priors, models = create_suite(
            ('mean', linspace(1/HOUR, 30/HOUR)),
            ('std', linspace(1/HOUR, 30/HOUR)))

    bayes_update(priors, models, [trip])
    
    posteriors = exp(priors)
    posteriors /= posteriors.sum()
    #posteriors = priors

    mean, std = meshgrid(param_ranges[0][1], param_ranges[1][1])
    pcolor(mean*HOUR, std*HOUR, posteriors)

    colorbar()
    xlabel('Speed [kph]')
    ylabel('Std. of Speed [kph]')
    xlim([1, 30])
    ylim([1, 30])
    show()
