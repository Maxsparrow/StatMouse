import pymysql
import random
import urllib
from Connections import *

def getsummonerids(amount=10):

    sdb = pymysql.connect(host=SQLhost,user=SQLuser,passwd=SQLpass,db="statmous_gamedata")
    cursor = sdb.cursor()

    query = ("SELECT summonerId FROM summoners")

    cursor.execute(query)

    results = cursor.fetchall()

    summonerids = []

    for summonerid in results:
        summonerids.append(summonerid[0])

    cursor.close()
    sdb.close()

    random.shuffle(summonerids)
    summonerids = summonerids[0:amount]

    return summonerids

class apirequest(object):
    #https://na.api.pvp.net/api/lol/na/v2.2/matchhistory/102935?api_key=0fb38d6c-f520-481e-ad6d-7ae773f90869
    urlbase = 'https://na.api.pvp.net/api/lol/'
    region = 'na'
    apikey = '?api_key=0fb38d6c-f520-481e-ad6d-7ae773f90869'

    def __init__(self,requesttype,**args):
        """Valid requesttypes are: matchhistory,match,items,champions"""
        self.requesttype=requesttype
        
        if requesttype == "matchhistory":
            self.url = self.urlbase + self.region+'/v2.2/matchhistory/'+str(args['summonerId'])+self.apikey
        elif requesttype == "match"
            self.url = self.urlbase + self.region+'/v2.2/match/'+str(args['matchId'])+self.apikey        
    
    def sendrequest(self):
        urllib.open(self.url)
        return False
        

summonerids = getsummonerids()
api1 = apirequest('matchhistory',summonerId=summonerids[1])
print api1.url



#from pymongo import MongoClient
#mdb = MongoClient()


