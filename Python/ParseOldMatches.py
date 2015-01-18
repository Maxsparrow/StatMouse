import sys
import os
sys.path.append(os.getcwd()+'/Python/')
from APIRequests import *

mcon = pymongo.MongoClient('localhost',27017)
mdb = mcon.games
gamescoll = mdb.full

print 'getting matchIds in mongo'
cursor = gamescoll.find()

matchIds = []
counter = 0
for record in cursor:
    m = match(record['matchId'])
    m.data = record
    m.fetchparsed()
    try:
        m.addtomongo('parsed')
        counter += 1
    except IOError as e:
        print str(e)
    if counter % 50 == 0:
        print 'Added %d matches to mongodb parsed collection so far' % counter
        
print 'Execution completed successfully, added %d matches to mongodb parsed collection' % counter
