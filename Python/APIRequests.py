import pymysql
import random
import urllib2
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
    urlbase = 'https://na.api.pvp.net/api/lol/'
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
        ##TODO: Switch to using requests module isntead of urllib
        while self.errorcounter <= 3:
            try:
                self.ratelimitcheck()		
                f = urllib2.urlopen(self.url)
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
        if len(apirequest.requesthistory)>8:
            if (datetime.datetime.now()-apirequest.requesthistory[-8]).seconds<10:
                print 'Pausing 10 seconds for rate limit'
                time.sleep(10)
        apirequest.requesthistory.append(datetime.datetime.now())
                    
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
            print 'Error '+str(statuscode)+' API service unavailable, waiting 5 minutes and trying again'
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
        apirequest.__init__(self)
        self.url = apirequest.urlbase + apirequest.region+'/v2.2/matchhistory/'+str(summonerId)+apirequest.apikey

    def getmatch(self):
        """Generator to return matchs one at a time"""
        if self.data == None:
            raise IOError('No api data. Use sendrequest method first.')
        elif 'matches' not in self.data:
            raise IndexError('No matches available for this summoner')
        for match in self.data['matches']:
            yield match
	
class match(apirequest):
    def __init__(self,matchId,includeTimeline=True):
        """Initialize with base values from apirequest and matchId"""
        apirequest.__init__(self)
        self.matchId = matchId
        self.parsed = None
        self.inmongo = {}
        self.includeTimeline = includeTimeline
        
    def fetchdata(self):
        ##Check if matchId already exists, if not, add to db and disconnect
        mcon = pymongo.MongoClient('localhost',27017)
        mdb = mcon.games
        gamescoll = mdb.full
        mdata = gamescoll.find_one({'matchId':self.matchId})
        if mdata is not None:
            self.inmongo['full'] = True
            self.data = mdata
        else:
            self.inmongo['full'] = False
            self.url = apirequest.urlbase + apirequest.region+'/v2.2/match/'+str(self.matchId)+apirequest.apikey+'&includeTimeline='+str(self.includeTimeline)
            self.sendrequest()
            self.addcustomstats()
            
    def fetchparsed(self):
        if self.parsed != None:
            raise IOError('Already fetched, use .parsed to view')
        parsedmatches = []
        mcon = pymongo.MongoClient('localhost',27017)
        mdb = mcon.games
        gamescoll = mdb.parsed
        cursor = gamescoll.find({'matchId':self.matchId})
        for record in cursor:
            parsedmatches.append(record)
        if parsedmatches != []:
            self.inmongo['parsed'] = True
            self.parsed = parsedmatches
        else:
            self.inmongo['parsed'] = False
            self.parsematch()                    

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

    def addtomongo(self,collection,newonly=True):
        """Adds current matchdata to mongodb database or updates an existing match in mongodb. Use collection to specify full or parsed matches"""
        if self.includeTimeline == True:
            assert 'timeline' in self.data, "No timeline in match data"
            
        if (newonly==True and self.inmongo[collection]==True):
            raise IOError('matchId already in '+collection+' collection')
            
        ##TODO: Add function or class for connecting to mongo
        results=[]                    
        mcon = pymongo.MongoClient('localhost',27017)
        mdb = mcon.games
        if collection == 'full':
            gamescoll = mdb.full           
            results = gamescoll.save(self.data)          
        elif collection == 'parsed':
            gamescoll = mdb.parsed
            for record in self.parsed:
                result = gamescoll.save(record)
                results.append(result)
        else:
            raise IOError('Invalid collection name')
        
        mcon.disconnect()
        return results 
          
    def parsematch(self):   
        assert 'timeline' in self.data, "No timeline in match data"     
        if self.data == None:
                raise IOError('No api data. Use getdata method first.')
                
        parsedmatches = []
        
        keystokeep = ['matchId','matchDuration','matchCreation']
        for index in range(10):
            parsedmatch = {}             
            
            parsedmatch = {k:self.data[k] for k in keystokeep}
            
            ##Match info
            parsedmatch['gameTowerKills'] = self.data['stats']['towerKills']  
            
            ##Participant info  
            parsedmatch['championId'] = self.data['participants'][index]['championId']
            parsedmatch['participantId'] = self.data['participants'][index]['participantId']    
            parsedmatch['playerPercGold'] = self.data['participants'][index]['stats']['goldEarnedPercentage']
            parsedmatch['KDA'] = self.data['participants'][index]['stats']['KDA']
            parsedmatch['winner'] = self.data['participants'][index]['stats']['winner']
            parsedmatch['teamId'] = self.data['participants'][index]['teamId']
            
            ##Summoner info
            for identity in self.data['participantIdentities']:
                if identity['participantId'] == parsedmatch['participantId']:
                    break    
            parsedmatch['summonerId'] = identity['player']['summonerId']
            parsedmatch['summonerName'] = identity['player']['summonerName']
            
            ##Team info
            for team in self.data['teams']:
                if team['teamId'] == parsedmatch['teamId']:
                    break
            parsedmatch['teamPercGold'] = team['goldEarnedPercentage']
            parsedmatch['teamTowerKills'] = team['towerKills']
            parsedmatch['teamDragonKills'] = team['dragonKills']
            parsedmatch['teamBaronKills'] = team['baronKills']
            
            ####Getting all the items out from timeline
            ordercounter = 0
            items = {}
            eventtimes = self.data['timeline']['frames']
            for eventtime in eventtimes:
                if 'events' not in eventtime:
                    continue
                for event in eventtime['events']:
                    if event['eventType'] == 'ITEM_PURCHASED' and event['participantId'] == parsedmatch['participantId']:
                        ##For each item we add, find the current count of that item in the itemlist, so we can name the item with a . on the end and the item count of that item
                        regex = re.compile(str(event['itemId']))
                        itemcounter = len([l for l in items if regex.search(l)])+1
                        items[str(event['itemId'])+'_'+str(itemcounter)] = ordercounter
                try:
                    ordercounter = max(items.values())+1
                except:
                    ordercounter = ordercounter
            parsedmatch['items'] = items
            
            parsedmatches.append(parsedmatch)
            
        self.parsed = parsedmatches
        
class championinfo(apirequest):
    def __init__(self):
        apirequest.__init__(self)
        self.url = apirequest.urlbase + 'static-data/' + apirequest.region+'/v1.2/champion/'+apirequest.apikey
        self.sendrequest()
        self.create_ids_table()
        
    def create_ids_table(self):
        self.ids = {k:v['id'] for k,v in self.data['data'].items()}
        
    def getId(self,championName):
        return self.ids[championName]
        
    def getName(self,championId):
        assert type(championId) == int, "championId must be an integer: %r" %championId
        return [k for k, v in self.ids.items() if v == championId][0]
        
class iteminfo(apirequest):
    def __init__(self):
        apirequest.__init__(self)   
        self.url = apirequest.urlbase + 'static-data/' + apirequest.region + '/v1.2/item/'+apirequest.apikey+'&itemListData=from,into'
        self.sendrequest()
        self.create_ids_table()
        self.data = self.data['data']
        for key in self.data:
            self.data[key]['final'] = 'into' not in self.data[key] or self.data[key]['name'][:7]=="Enchant"
        
    def create_ids_table(self):
        self.ids = {k:v['name'] for k,v in self.data['data'].items()}
        
    def getId(self,itemName):
        return int([k for k, v in self.ids.items() if v == itemName][0])
        
    def getName(self,itemId):
        assert type(itemId) == int, "itemId must be an integer: %r" %itemId
        return self.ids[str(itemId)]
        
def getbadmatch():
    ##This is for fixing a team goldEarnedPercentage bug
    mcon = pymongo.MongoClient('localhost',27017)
    mdb = mcon.games
    gamescoll = mdb.full
    
    curmatch = gamescoll.find_one({'teams.0.goldEarnedPercentage':{'$exists':0}})
    mcon.disconnect()
    
    print curmatch['matchId']
    match1 = match(curmatch['matchId'])
    match1.fetchdata()
    match1.addcustomstats()
    print match1.addtomongo()

