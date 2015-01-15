import pymongo
import re

#mcon = pymongo.MongoClient('localhost',27017)
#mdb = mcon.games
#gamescoll = mdb.games

#query = {'participants.championId':81}
#cursor = gamescoll.find(query)

#parsedmatchlist = []
#for match in cursor:
#    parsedmatch = parsematch(match)
#    parsedmatchlist.append(parsedmatch)

def parsematch(match):
    parsedmatch = {}
    
    ##Match info
    parsedmatch['matchId'] = match['matchId']
    parsedmatch['gameTowerKills'] = match['stats']['towerKills']
    
    ##Participant info
    for participant in match['participants']:
        if participant['championId'] == 78:
            break ##I want this to break while participant is the one that contains the championId we want          
    parsedmatch['playerPercGold'] = participant['stats']['goldEarnedPercentage']
    parsedmatch['championId'] = participant['championId']
    parsedmatch['participantId'] = participant['participantId']
    
    ##Summoner info
    for identity in match['participantIdentities']:
        if identity['participantId'] == parsedmatch['participantId']:
            break    
    parsedmatch['summonerId'] = identity['player']['summonerId']
    parsedmatch['summonerName'] = identity['player']['summonerName']
    
    ##Team info
    parsedmatch['teamId'] = participant['teamId']
    for team in match['teams']:
        if team['teamId'] == parsedmatch['teamId']:
            break
    parsedmatch['teamPercGold'] = team['goldEarnedPercentage']
    
    ####Getting all the items out from timeline
    ordercounter = 0
    items = {}
    eventtimes = match['timeline']['frames'][1:]
    for eventtime in eventtimes:
        for event in eventtime['events']:
            if event['eventType'] == 'ITEM_PURCHASED' and event['participantId'] == parsedmatch['participantId']:
                regex = re.compile(str(event['itemId']))
                itemcounter = len([l for l in items if regex.search(l)])+1
                items[str(event['itemId'])+'.'+str(itemcounter)] = ordercounter
        ordercounter = max(items.values())+1
    parsedmatch['items'] = items
    return parsedmatch
        
                
####Consider separate method/function for item parser to make it more modular. takes a list of eventtimes and returns a dict with each item and the order it came in

####This should probably just be included as a method of the match class. Just require an argument for addtomongo for two different collections 'raw' and 'parsed'. Consider renaming the db to 'matches' from 'games' when possible
