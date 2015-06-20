import sys
import os
sys.path.append(os.getcwd()+'/Python/')
from APIRequests import *
from logger import logger

patchdate = datetime.date.today() - datetime.timedelta(days=7)

def getmatchIds(amount = 1000):
    matchIds = []
    s = summoners()
    while len(matchIds)<amount:
        mh = matchhistory(s.getid())
        try:
            mh.sendrequest()
        except IOError as e:
            logger.warning('%s, skipping to next', str(e))
            continue
        try:
            for record in mh.getmatch():
                if datetime.date.fromtimestamp(record['matchCreation']/1000) > patchdate and record['matchId'] not in matchIds and record['queueType']=='RANKED_SOLO_5x5':
                    matchIds.append(record['matchId'])
                    if len(matchIds) % 50 == 0:
                        logger.info('Currently have %d matchIds', len(matchIds))
        except IndexError as e:
            logger.warning('%s, skipping to next', str(e))
            continue ##If there are no matches available for this summoner, skip to next
    logger.info('Ready to get match data, have %d matchIds', len(matchIds))
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
            logger.warning('%s. Cannot get match data, skipping to next', str(e))
            continue
        try:
            m.fetchparsed()
        except IOError as e:
            logger.warning('%s. Cannot get parsed data, will add full data if possible', str(e))
        except AssertionError as e: ##If there is no timeline data, skip this
            logger.warning('%s. Skipping to next', str(e))
            continue
        
        ##Try to add to mongodb, will output error if it already is there
        try:
            m.addtomongo('full')
            fullcounter += 1
        except IOError as e:
            logger.warning('%s. Cannot add full data, will add parsed data if possible', str(e))
        try:
            m.addtomongo('parsed')
            parsedcounter += 1
        except IOError as e:
            logger.warning('%s, Cannot add parsed data, moving on to next match', str(e))
        if fullcounter % 50 == 0:
            logger.info('Added %d games to MongoDB full collection and %d games to MongoDB parsed collection so far this session', fullcounter, parsedcounter)
            
    logger.info('Operation completed successfully, added %d games to MongoDB full collection and %d games to MongoDB parsed collection', fullcounter, parsedcounter)
            
##Also consider making this function and the one above part of the above classes. or maybe subclasses

script, amount = sys.argv

logger.info('Getting %s games after date of %s', amount, patchdate)
matchIds = getmatchIds(int(amount))
getgamesmongo(matchIds)

