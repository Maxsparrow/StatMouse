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

championId = 81
#participantonly = 	{'$unwind':'$participants'},{'$project':{'participants':1}},{'$match':{'$participants.championId':championId}}
						

#query = [{'$match':{'$participants.championId':championId}},{'$project':{'championId':{participantonly,{'$project':{'$participants.championId':1}}}},'participantId':1,'playerPercGold':'$stats.goldEarnedPercentage',			'KDA':'$stats.KDA','winner':'$stats.winner'}},{'$limit':1}]
						
				# {matchId:1,
				# matchDuration:1,
				# matchCreation:1,
				# gameTowerKills:'$stats.towerKills'
			# }
			
def parsematch(match):
    parsedmatch = {}
    
    ##Match info
    parsedmatch['matchId'] = match['matchId']
    parsedmatch['gameTowerKills'] = match['stats']['towerKills']
    parsedmatch['matchDuration'] = match['matchDuration']
    parsedmatch['matchCreation'] = match['matchCreation']
    
    ##Participant info
    for participant in match['participants']:
        if participant['championId'] == 78:
            break ##I want this to break while participant is the one that contains the championId we want     
    parsedmatch['championId'] = participant['championId']
    parsedmatch['participantId'] = participant['participantId']    
    parsedmatch['playerPercGold'] = participant['stats']['goldEarnedPercentage']
    parsedmatch['KDA'] = participant['stats']['KDA']
    parsedmatch['winner'] = participants['stats']['winner']
    
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
    parsedmatch['teamTowerKills'] = team['towerKills']
    parsedmatch['teamDragonKills'] = team['dragonKills']
    parsedmatch['teamBaronKills'] = team['baronKills']
    
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
