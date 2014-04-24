
from numpy import *
from bisect import bisect_right

def distance(point1, point2):
    return sqrt(sum((point2 - point1)**2))

class Path(object):

    def __init__(self, points):
        self.points = array(points, dtype=float)
        self._compute_segments()
   
    @property
    def start(self): return self.points[0]

    @property
    def end(self): return self.points[-1]
    
    def _compute_segments(self):
        self.segments = diff(self.points, axis=0)
        self.segment_lengths = sqrt(sum(self.segments**2, axis=1))
        self.cum_segment_lengths = cumsum(self.segment_lengths)
        self.total_length = sum(self.segment_lengths)

    def __call__(self, length):
        index = bisect_right(self.cum_segment_lengths, length)
        if index < 0 or index > len(self.cum_segment_lengths):
            raise ValueError(length)

        if index > 0:
            length  -= self.cum_segment_lengths[index-1]
        p = float(length)/self.segment_lengths[index]
        return self.points[index] + p*self.segments[index]

    def __add__(self, other_path):
        if (self.points[-1] == other_path.points[0]).all():
            points = self.points[:-1, :]
        else:
            points = self.points
        return Path(vstack((points, other_path.points))) 

def single_segment_path(length, offset=[0, 0]):
    offset = array(offset)
    return Path(offset + array([[0, 0], [length, 0]]))

def corner_path(length, offset=[0, 0]):
    offset = array(offset)
    return Path(offset + array([[0, 0], 
                                [length/2., 0], 
                                [length/2., length/2.]]))

if __name__ == '__main__':
    path = single_segment_path(10)
    path += corner_path(10, offset=path.end)
    print path.points
    print path.total_length
    print path.segments
    print path(1), path(7), path(16), path(19)
    
