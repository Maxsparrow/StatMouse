import pymysql
import random
import urllib
import json
import pymongo
import datetime
import time
from sys import argv
from Connections import *

patchdate = datetime.date(2014,12,11)

class summoners(object):
    def __init__(self,amount):
        """Initialize list for summoner ids"""
        self.ids = []
        self.getids(amount)
    
    def __repr__(self):
        return str(self.ids)

    def setids(self,amount):
        """Fetches a certain number of ids from MySQL server and adds them to the ids list"""
        scon = pymysql.connect(host=SQLhost,user=SQLuser,passwd=SQLpass,db="statmous_gamedata")
        cursor = scon.cursor()

        query = ("SELECT summonerId FROM summoners")

        cursor.execute(query)

        results = cursor.fetchall()

        summonerids = []

        for summonerid in results:
            summonerids.append(summonerid[0])

        cursor.close()
        scon.close()
        
        ##Randomly sort the summoner ids and add the desired amount to the list
        random.shuffle(summonerids)
        for summonerid in summonerids[0:amount]:
            self.ids.append(summonerid)
			
	def getid(self):
		"""Pulls from the list of summoner ids we created one at a time"""
		for id in self.ids:
			yield id

class apirequest(object):
    #Example URL:
    #https://na.api.pvp.net/api/lol/na/v2.2/matchhistory/102935?api_key=0fb38d6c-f520-481e-ad6d-7ae773f90869
    urlbase = 'http://na.api.pvp.net/api/lol/'
    region = 'na'
    apikey = '?api_key=0fb38d6c-f520-481e-ad6d-7ae773f90869'
    ##TODO: add functionality to track requests to prevent hitting rate limit, and response codes
    requesttracker = []

    def __init__(self,requesttype,**args):
        """Valid requesttypes are: matchhistory,match,items,champions
        Make sure to declare named variables that are needed like summonerId or matchId"""
		self.data = None
        self.requesttype=requesttype
        
        if requesttype == "matchhistory":
            self.url = self.urlbase + self.region+'/v2.2/matchhistory/'+str(args['summonerId'])+self.apikey
        elif requesttype == "match":
            if 'includeTimeline' in args:
                incTlStr = '&includeTimeline='+str(args['includeTimeline'])
            else:
                incTlStr = ''
            self.url = self.urlbase + self.region+'/v2.2/match/'+str(args['matchId'])+self.apikey+incTlStr                        
    
    def __repr__(self):
		if self.data != None:
			return str(self.data)
        return self.url
    
    def sendrequest(self):
        """Sends a request to the server based on init above"""
        attemptcount = 0
		while attemptcount <= 5:
			try:		
				f = urllib.urlopen(self.url)
				jsondata = f.read()
				apidata = json.loads(jsondata)
				self.data = apidata
				break
			except:
				attemptcount += 1
				print 'Could not retrieve apidata, waiting one minute then retrying'
				time.sleep(60)
				if attemptcount == 5:
					print 'Not able to retrieve apidata, returning None value'
					self.data = None
    
class matchhistory(apirequest):
	def __init__(self,summonerId):
		self.url = apirequest.urlbase + apirequest.region+'/v2.2/matchhistory/'+str(summonerId)+apirequest.apikey
		
	def getmatchId(self):
	"""Generator to return matchIds one at a time"""
		for match in self.data['matches']:
			yield match['matchId']
	
class match(apirequest):
    def __init__(self,matchId,includeTimeline=False):
        """Initialize with url to get matchdata"""
		self.url = apirequest.urlbase + apirequest.region+'/v2.2/match/'+str(matchId)+apirequest.apikey+str(includeTimeline)  
        
    def addcustomstats(self):
        """Adds custom fields to the match data for participants,teams, and the main frames"""
        
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
        """Adds current matchdata to mongodb database; run after adding custom stats above"""
        mcon = pymongo.MongoClient('localhost',27017)
        mdb = mcon.games
        gamescoll = mdb.games
        
        ##Check if matchId already exists, if not, add to db and disconnect
        mcursor = gamescoll.find({'matchId':self.data['matchId']})
        counter = 0         
        for item in mcursor: counter += 1
        if counter == 0:            
            result = gamescoll.insert(self.data)
        mcon.disconnect()
        return result
                
        
def getmatchIds(amount = 1000):
    cursummoners = summoners(int(amount/2))
    matchIds = []
    counter = 0
    reqcounter = 0
    while len(matchIds) < amount:
        matchhistory = apirequest('matchhistory',summonerId=cursummoners.ids[counter])
        matchhistory.sendrequest()
        reqcounter += 1
        if reqcounter == 8:
            print 'hit rate limit waiting 10 seconds'
            reqcounter = 0
            time.sleep(10)
        if 'matches' in matchhistory.data:
            for match in matchhistory.data['matches']:
                if datetime.date.fromtimestamp(match['matchCreation']/1000) > patchdate:
                    matchIds.append(match['matchId'])
        counter += 1
        if counter >= len(cursummoners.ids):
            cursummoners.getids(int(amount/2))
            print 'added %d more summonerids to summonerid list' % int(amount/2)
            
    return matchIds
    
def getgamesmongo(amount):        
    matchIds = getmatchIds(amount)
    reqcounter = 0
    for curmatchId in matchIds:
        curmatchreq = apirequest('match',matchId=curmatchId,includeTimeline=True)
        curmatchreq.sendrequest()
        reqcounter += 1
        if reqcounter == 8:
            print 'hit rate limit waiting 10 seconds'
            reqcounter = 0
            time.sleep(10)    
        if 'matchId' in curmatchreq.data:
            curmatch = match(curmatchreq.data)
            curmatch.addcustomstats()
            print curmatch.addtomongo()    
            
##TODO make match and matchhistory classes inheriting from apirequest?
##Also consider making this function and the one above
script, amount = argv

getgamesmongo(int(amount))


