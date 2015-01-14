import pymongo
import re

mcon = pymongo.MongoClient('localhost',27017)
mdb = mcon.games
gamescoll = mdb.games

query = {'participants.championId':81}
cursor = gamescoll.find(query)

parsedmatchlist = []
for match in cursor:
    parsedmatch = parsematch(match)
    parsedmatchlist.append(parsedmatch)

def parsematch(match):
    parsedmatch = {}
    for participant in match['participants']:
        if participant['championId'] == 81:
            break ##I want this to break while participant is the one that contains the championId we want
    parsedmatch['playerPercGold'] = participant['goldEarnedPercentage']
    parsedmatch['championId'] = participant['championId']
    parsedmatch['participantId'] = participant['participantId']
    teamId = participant['teamId']
    for team in match['teams']:
        if team['teamId'] == teamId:
            break
    parsedmatch['teamPercGold'] = team['goldEarnedPercentage']
    
    ####Getting all the items out from timeline
    ordercounter = 0
    items = {}
    eventtimes = match['timeline']['frames']
    for eventtime in eventtimes:
        for event in eventtime:
            if event['type'] == 'ITEM_PURCHASED' and event['participantId'] == parsedmatch['participantId']: ##Need to find out the right parameters for this
                itemcounter = re.search(items,event['itemId']) ##Donno syntax
                itemcounter += 1
                items[event['itemId']+str(itemcounter)] = ordercounter
        ordercounter += 1
                
####Consider separate method/function for item parser to make it more modular. takes a list of eventtimes and returns a dict with each item and the order it came in

####This should probably just be included as a method of the match class. Just require an argument for addtomongo for two different collections 'raw' and 'parsed'. Consider renaming the db to 'matches' from 'games' when possible
