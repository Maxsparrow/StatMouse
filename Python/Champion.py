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
        itemdata = [{k:v for k,v in row.items() if k=='items'}['items'] for row in self.rawdata]
        self.itemdata = DataFrame(itemdata)
        ##TODO filter itemdata for only things ending in _1
        ##TODO parse itemdata in ways suggested in my notebook
