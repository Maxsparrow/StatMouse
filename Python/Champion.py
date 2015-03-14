import sys
import os
import pandas as pd
from pandas import DataFrame, Series
sys.path.append(os.getcwd()+'/Python/')
from Connections import *
from APIRequests import *
from sklearn.cluster import KMeans
from sklearn.ensemble import RandomForestClassifier

class Champion(object):
    def __init__(self,championName=None,championId=None):
        assert championId or championName
        self.rawdata = None
        self.clustercount = None
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
        ##TODO parse itemdata in ways suggested in my notebook
        
    def set_clusters(self,clustercount):
        self.clustercount = clustercount
        clustdata = self.itemdata.filter_first_item()
        clustdata = clustdata.fillna(100)
        kmeans = KMeans(init='k-means++',n_clusters=clustercount)
        kmeans.fit(clustdata)
        self.itemdata.set_cluster_labels(kmeans.labels_)
        self.gamedata['cluster'] = kmeans.labels_
        
    def set_builds(self):
        assert self.clustercount, "Use set_clusters method first"
        for cluster in range(self.clustercount):
            self.builds.append(Build(self,cluster))        
        
class Build(object):
    """Build for a Champion, can pull different item data from a build"""
    def __init__(self,champion,cluster):
        self.itemdata = champion.itemdata.filter_cluster(cluster)
        self.gamedata = champion.gamedata[champion.gamedata.cluster == cluster]
        self.cluster = cluster
        
    def set_starting_items(self):
        """Add best starting items to this build"""
        ##Start by looping through itemdata and finding all the starting items for each record
        itemcombos = []
        for row in self.itemdata.data.iterrows():
            row = row[1]
            row = row[row==0]
            row = row[row.index!='cluster']
            itemcombo = ";".join(list(row.index))
            itemcombos.append(itemcombo)
        itemcombos = Series(itemcombos,name='startingitems')
        ##Add the item combinations to the gamedata dataframe
        gamedata = self.gamedata.copy()
        gamedata = pd.concat([gamedata,itemcombos])
        gamedata.rename(columns={0:'startingitems'},inplace=True)
        colstokeep = ['KDA','gameTowerKills','matchDuration','playerPercGold','teamBaronKills',
        'teamDragonKills','teamId','teamPercGold','teamTowerKills','winner','startingitems']
        return gamedata[colstokeep]
        ##TODO There seems to be an issue when concating the item combos, many show as NaN
        ##TODO implement and test this random forest
        rf = RandomForestClassifier()
        rf.fit(gamedata[gamedata.columns[gamedata.columns!='winner']],gamedata['winner'])
        rf.feature_importances_
        
    def set_final_items(self):
        pass
        
    def set_build_order(self):
        pass
        
class ItemData(object):
    def __init__(self,rawitemdata):
        """Pass in a pandas dataframe with only item data from a game data pull"""
        self.data = rawitemdata
        
    def set_cluster_labels(self,clusterlabels):
        self.data['cluster'] = clusterlabels

    def filter_first_item(self):
        cols = self.data.columns
        cols = [col for col in cols if col[-2::]=='_1']
        return self.data[cols]        
        
    def filter_cluster(self,cluster):
        return ItemData(self.data[self.data.cluster == cluster])

    def create_order_table(self,itemId):
        pass
        
    def create_item_table(self,order):
        pass
        
####Test on Ezreal
champs = championinfo()
items = iteminfo()
    
ez = Champion('Ezreal')
ez.make_split_data()
ez.set_clusters(3)
ez.set_builds()
