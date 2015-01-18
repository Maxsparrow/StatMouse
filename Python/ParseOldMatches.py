import sys
sys.path.append(os.getcwd()+'/Python/')
import APIRequests

mcon = pymongo.MongoClient('localhost',27017)
mdb = mcon.games
gamescoll = mdb.full

cursor = gamescoll.find({'matchId':{'$exists':1}})
matchIds = []
for record in cursor:
    matchIds.append(record['matchId'])
    
for matchId in matchIds:
    m = match(matchId)
    m.fetchdata()
    m.fetchparsed()
    try:
        m.addtomongo('full')
    except IOError as e:
        print str(e)
    try:
        m.addtomongo('parsed')
    except IOError as e:
        print str(e)

