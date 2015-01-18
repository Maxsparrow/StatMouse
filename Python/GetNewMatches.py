import sys
sys.path.append(os.getcwd()+'/Python/')
import APIRequests

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
            for match in mh.getmatch():
                if datetime.date.fromtimestamp(match['matchCreation']/1000) > patchdate and match['matchId'] not in matchIds:
                    matchIds.append(match['matchId'])
                    if len(matchIds) % 50 == 0:
                        print 'Currently have %d matchIds' % len(matchIds)
        except IndexError as e:
            print str(e) + ', skipping to next'
            continue ##If there are no matches available for this summoner, skip to next
    print 'Ready to get match data, have %d matchIds' % len(matchIds)
    return matchIds
    
def getgamesmongo(matchIds):
    """Pass a list of matchIds to add each match to mongodb"""
    counter = 0
    for matchId in matchIds:       
        m = match(matchId)
        try:
            m.fetchdata()
        except IOError as e:
            print str(e) + ', skipping to next'
            continue
        m.addcustomstats()
        ##Check to see if it is already in mongodb before adding, we only want new matches
        if not m.inmongo:  
            try:
                m.addtomongo()
                counter += 1
            except:
                print 'Error adding to mongodb, skipping to next'
                continue
        if counter % 50 == 0:
            print 'Added %d games to MongoDB so far this session' % counter     
    print 'Operation completed successfully, added %d games to MongoDB' % counter
            
##Also consider making this function and the one above part of the above classes. or maybe subclasses

script, amount = sys.argv

matchIds = getmatchIds(int(amount))
getgamesmongo(matchIds)

