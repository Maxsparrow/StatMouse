import os
sys.path.append(os.getcwd()+'/Python/')
from Connections import *
from APIRequests import *

class Champion(object):
    def __init__(self,id=None,name=None):
        assert championId or championName
