import sys
import os
import pandas
from pandas import DataFrame
sys.path.append(os.getcwd()+'/Python/')
from Connections import *
from APIRequests import *

class Champion(object):
    def __init__(self,championName=None,championId=None):
        assert championId or championName
        self.rawdata = None
        self.builds = []
        if championName:
            champtable = championinfo()
            self.id = champtable.getId(championName)
        else:
            self.id = championId
        
    def fetch_parsed(self):  
        results=[]                    
        mcon = pymongo.MongoClient('localhost',27017)
        mdb = mcon.games
        gamescoll = mdb.parsed
        
        cursor = gamescoll.find({'championId':self.id},{'_id':0})
        
        for row in cursor:
            results.append(row)
            
        self.rawdata = results
        
    def make_split_data(self):
        if not self.rawdata:
            self.fetch_parsed()
            
        gamedata = [{k:v for k,v in row.items() if k!='items'} for row in self.rawdata]
        self.gamedata = DataFrame(gamedata)
        rawitemdata = [{k:v for k,v in row.items() if k=='items'}['items'] for row in self.rawdata]
        rawitemdata = DataFrame(rawitemdata)
        self.itemdata = ItemData(rawitemdata)
        ##TODO filter itemdata for only things ending in _1
        ##TODO parse itemdata in ways suggested in my notebook
        
    def set_clusters(self):
        pass
        
    def set_builds(self):
        builds.append(Build(self,cluster))
        
        
class Build(object):
    """Build for a Champion, can pull different item data from a build"""
    def __init__(self,champion,cluster):
        self.itemdata = champion.itemdata.filter_cluster(cluster)
        self.gamedata = champion.gamedata[champion.gamedata.cluster == cluster]
        self.cluster = cluster
        
    def set_starting_items(self):
        pass
        
    def set_final_items(self):
        pass
        
    def set_build_order(self):
        pass
        
class ItemData(object):
    def __init__(self,data):
        """Pass in a pandas dataframe with only item data from a game data pull"""
        self.data = data
        
    def filter_cluster(self,cluster):
        return self.data[self.data.cluster == cluster]

    def filter_first_item(self):
        pass

    def create_order_table(self,itemId):
        pass
        
    def create_item_table(self,order):
        pass
        
    
