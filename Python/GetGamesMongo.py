import pymysql
import random
import urllib
import json
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
    urlbase = 'http://na.api.pvp.net/api/lol/'
    region = 'na'
    apikey = '?api_key=0fb38d6c-f520-481e-ad6d-7ae773f90869'

    def __init__(self,requesttype,**args):
        """Valid requesttypes are: matchhistory,match,items,champions
        Make sure to declare named variables that are needed like summonerId or matchId"""
        self.requesttype=requesttype
        
        if requesttype == "matchhistory":
            self.url = self.urlbase + self.region+'/v2.2/matchhistory/'+str(args['summonerId'])+self.apikey
        elif requesttype == "match":
            if 'includeTimeline' in args:
                inctlstr = '&includeTimeline='+args['includeTimeline']
            else:
                inctlstr = ''
            self.url = self.urlbase + self.region+'/v2.2/match/'+str(args['matchId'])+self.apikey+inctlstr                        
    
    def sendrequest(self):
        f = urllib.urlopen(self.url)
        jsondata = f.read()
        apidata = json.loads(jsondata)
        return apidata
        
#lass match(object):

summonerids = getsummonerids()
api1 = apirequest('matchhistory',summonerId=summonerids[1])
apidata1 = api1.sendrequest()
api2 = apirequest('match',matchId=apidata1['matches'][0]['matchId'],includeTimeline='True')
apidata2 = api2.sendrequest()

print apidata2
print api2.url

#from pymongo import MongoClient
#mdb = MongoClient()


