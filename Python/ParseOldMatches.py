import sys
sys.path.append(os.getcwd()+'/Python/')
import APIRequests

mcon = pymongo.MongoClient('localhost',27017)
mdb = mcon.games
gamescoll = mdb.full

print 'getting matchIds in mongo'
cursor = gamescoll.find()

matchIds = []
for record in cursor:
    matchIds.append(record['matchId'])
    
print 'Parsing %d matches' % len(matchIds)
    
counter = 0
for matchId in matchIds:
    m = match(matchId)
    m.fetchdata()
    m.fetchparsed()
    try:
        m.addtomongo('parsed')
        counter += 1
    except IOError as e:
        print str(e)
    if counter % 50 == 0:
        print 'Added %d matches to mongodb parsed collection so far' % counter
        
print 'Execution completed successfully, added %d matches to mongodb parsed collection' % counter
