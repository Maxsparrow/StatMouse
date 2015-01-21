import sys
import os
sys.path.append(os.getcwd()+'/Python/')
from APIRequests import *

patchdate = datetime.date(2015,1,15)

def getmatchIds(amount = 1000):
    matchIds = []
    s = summoners()
    while len(matchIds)<amount:
        mh = matchhistory(s.getid())
        try:
            mh.sendrequest()
        except IOError as e:
            print str(e) + ', skipping to next'
            continue
        try:
            for record in mh.getmatch():
                if datetime.date.fromtimestamp(record['matchCreation']/1000) > patchdate and record['matchId'] not in matchIds and record['queueType']=='RANKED_SOLO_5x5':
                    matchIds.append(record['matchId'])
                    if len(matchIds) % 50 == 0:
                        print 'Currently have %d matchIds' % len(matchIds)
        except IndexError as e:
            print str(e) + ', skipping to next'
            continue ##If there are no matches available for this summoner, skip to next
    print 'Ready to get match data, have %d matchIds' % len(matchIds)
    return matchIds
    
def getgamesmongo(matchIds):
    """Pass a list of matchIds to add each match to mongodb"""
    fullcounter = 0
    parsedcounter = 0
    for matchId in matchIds:       
        m = match(matchId)
        try:
            m.fetchdata()
        except IOError as e:
            print str(e) + '. Cannot get match data, skipping to next'
            continue
        try:
            m.fetchparsed()
        except IOError as e:
            print str(e) + '. Cannot get parsed data, will add full data if possible'
        
        ##Try to add to mongodb, will output error if it already is there
        try:
            m.addtomongo('full')
            fullcounter += 1
        except IOError as e:
            print str(e) + '. Cannot add full data, will add parsed data if possible'
        try:
            m.addtomongo('parsed')
            parsedcounter += 1
        except IOError as e:
            print str(e) + ', Cannot add parsed data, moving on to next match'
        if fullcounter % 50 == 0:
            print 'Added %d games to MongoDB full collection and %d records to MongoDB parsed collection so far this session' % (fullcounter, parsedcounter)
    print 'Operation completed successfully, added %d games to MongoDB full collection and %d games to MongoDB parsed collection' % (fullcounter, parsedcounter)
            
##Also consider making this function and the one above part of the above classes. or maybe subclasses

script, amount = sys.argv

matchIds = getmatchIds(int(amount))
getgamesmongo(matchIds)

