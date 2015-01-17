import pymysql
import random
import urllib
import json
import pymongo
import datetime
import time
import re
import sys
import os
sys.path.append(os.getcwd()+'/Python/')
from Connections import *

class summoners(object):
    def __init__(self):
        """Initialize list for summoner ids"""
        self.ids = []
        self.ids_used = 0
        self.setids()
    
    def __repr__(self):
        print str(len(self.ids))+' Summoner Ids'
        print 'Next 10 Summoner Ids:'
        return str(self.ids[self.ids_used:self.ids_used+10])

    def setids(self):
        """Fetches a certain number of ids from MySQL server and adds them to the ids list"""
        scon = pymysql.connect(host=SQLhost,user=SQLuser,passwd=SQLpass,db="statmous_gamedata")
        cursor = scon.cursor()

        query = ("SELECT summonerId FROM summoners")

        cursor.execute(query)

        results = cursor.fetchall()

        summonerids = []

        for summonerid in results:
            self.ids.append(summonerid[0])

        cursor.close()
        scon.close()
        
        ##Randomly sort the summoner ids and add the desired amount to the list
        random.shuffle(self.ids)
        
    def getid(self):
        """Pulls from the list of summoner ids we created one at a time"""
        self.ids_used+=1 
        try:
            return self.ids[self.ids_used-1]
        except:
            raise IndexError('Ran out of summonerids, use reset_ids_used to reset counter')
        
    def reset_ids_used(self):
        self.ids_used=0

class apirequest(object):
    #Example URL:
    #http://na.api.pvp.net/api/lol/na/v2.2/matchhistory/102935?api_key=0fb38d6c-f520-481e-ad6d-7ae773f90869
    urlbase = 'http://na.api.pvp.net/api/lol/'
    region = 'na'
    apikey = '?api_key=0fb38d6c-f520-481e-ad6d-7ae773f90869'
    requesthistory = []

    def __init__(self):
        """Set base data for apirequests"""
        self.data = None     
        self.errorcounter = 0        

    def __repr__(self):
        if self.data != None:
            return str(self.data)
        else:
            return self.url

    def sendrequest(self):
        """Sends a request to the server based on init above"""
        while self.errorcounter <= 3:
            try:
                self.ratelimitcheck()		
                f = urllib.urlopen(self.url)
                jsondata = f.read()
                apidata = json.loads(jsondata)
                self.data = apidata
                break
            except:
                if self.errorcounter == 3:
                    self.errorcounter = 0
                    raise IOError('Unknown error. Cannot retrieve apidata after 3 attempts')
                else:  
                    self.errorcounter += 1                  
                    print 'Could not retrieve apidata, retrying (attempt #%d)' % self.errorcounter
                    time.sleep(5)
        ##Check the status of the data returned for error codes:
        if 'status' in self.data and self.data['status']['status_code']!=200:
            self.statuscheck()
        elif self.errorcounter > 0:
            print 'Retry succeeded'
            self.errorcounter = 0
            
    def ratelimitcheck(self):
        ##Only allow 8 requests every 10 seconds to stay within the rate limit
        if len(self.requesthistory)>8:
            if (datetime.datetime.now()-self.requesthistory[-8]).seconds<10:
                print 'Pausing 10 seconds for rate limit'
                time.sleep(10)
        self.requesthistory.append(datetime.datetime.now())
                    
    def statuscheck(self):
        statuscode = self.data['status']['status_code']
        if statuscode == 429:
            print 'Error 429 Rate limit exceeded, pausing 10 seconds and trying again'
            self.errorcounter += 1
            time.sleep(10)
            if self.errorcounter <= 5:
                self.sendrequest()
            else:
                self.errorcounter = 0
                raise IOError('Hit error 5 times, cannot pull api data')                
        elif statuscode == 503 or statuscode == 500:
            print 'Error '+statuscode+' API service unavailable, waiting 5 minutes and trying again'
            self.errorcounter += 1
            time.sleep(300)
            if self.errorcounter <= 5:
                self.sendrequest()
            else:
                self.errorcounter = 0
                raise IOError('Hit error 5 times, cannot pull api data')
        elif statuscode == 400 or statuscode == 401 or statuscode == 404:
            raise IOError('Bad request, unable to pull api data')
    
class matchhistory(apirequest):
    def __init__(self,summonerId):
        self.url = apirequest.urlbase + apirequest.region+'/v2.2/matchhistory/'+str(summonerId)+apirequest.apikey
        apirequest.__init__(self,self.url)

    def getmatch(self):
        """Generator to return matchs one at a time"""
        if self.data == None:
            raise IOError('No api data. Use sendrequest method first.')
        elif 'matches' not in self.data:
            raise IndexError('No matches available for this summoner')
        for match in self.data['matches']:
            yield match
	
class match(apirequest):
    def __init__(self,matchId):
        """Initialize with base values from apirequest and matchId"""
        apirequest.__init__(self)
        self.matchId = matchId
        
    def fetchdata(self,includeTimeline=True):
        ##Check if matchId already exists, if not, add to db and disconnect
        mdata = gamescoll.find_one({'matchId':self.matchId})
        if mdata == None
            self.data = mdata
        else:
            self.url = apirequest.urlbase + apirequest.region+'/v2.2/match/'+str(matchId)+apirequest.apikey+'&includeTimeline='+str(includeTimeline)
            self.sendrequest()

    def addcustomstats(self):
        """Adds custom fields to the match data for participants,teams, and the main frames"""
        if self.data == None:
            raise IOError('No api data. Use getdata method first.')

        ##Find total gold for each team and the whole match
        team100Gold = 0
        team200Gold = 0
        totalGameGold = 0
        for participant in self.data['participants']:
            totalGameGold += participant['stats']['goldEarned']
            if participant['teamId'] == 100:
                team100Gold += participant['stats']['goldEarned']
            elif participant['teamId'] == 200:
                team200Gold += participant['stats']['goldEarned']

        ##Adds custom fields to teams frame
        gameTowerKills = 0
        for team in self.data['teams']:
            gameTowerKills += team['towerKills']  
            if team['teamId'] == 100:
                team['goldEarned'] = team100Gold
                team['goldEarnedPercentage'] = round(float(team['goldEarned'])/totalGameGold,6)
            elif team['teamId'] == 200:
                team['goldEarned'] = team200Gold        
                team['goldEarnedPercentage'] = round(float(team['goldEarned'])/totalGameGold,6)

        ##Adds custom fields to the participants frames
        for participant in self.data['participants']:
            participant['stats']['goldEarnedPercentage'] = round(float(participant['stats']['goldEarned'])/totalGameGold,6)
            participant['stats']['KDA'] = round(float(participant['stats']['kills']+participant['stats']['assists'])/(participant['stats']['deaths']+1),6)

        ##Adds custom fields to the main frame
        self.data['stats'] = {'goldEarned':totalGameGold,'towerKills':gameTowerKills}

    def addtomongo(self):
        """Adds current matchdata to mongodb database or updates an existing match in mongodb"""
        mcon = pymongo.MongoClient('localhost',27017)
        mdb = mcon.games
        gamescoll = mdb.games              
        result = gamescoll.save(self.data)
        mcon.disconnect()
        return result  
        
def getbadmatch(self):
    ##This is for fixing a team goldEarnedPercentage bug
    mcon = pymongo.MongoClient('localhost',27017)
    mdb = mcon.games
    gamescoll = mdb.games
    
    curmatch = gamescoll.find_one({'teams.0.goldEarnedPercentage':0})
    #curmatch = gamescoll.find_one({'teams.0.goldEarnedPercentage':{'$exists':0}})
    mcon.disconnect()
    
    match1 = match(curmatch['matchId'])
    match1.fetchdata()
    match1.addcustomstats()
    match1.addtomongo()

