import mysql.connector
import random
from Connections import *

def getsummonerids(amount=10):

    attemptcount = 0
    while attemptcount <= 5:
        try:
            sdb = mysql.connector.connect(host=SQLhost,user=SQLuser,passwd=SQLpass,db="statmous_gamedata")
            cursor = sdb.cursor()

            query = ("SELECT summonerId FROM summoners LIMIT 10000")

            cursor.execute(query)

            results = cursor.fetchall()
            break
        except mysql.connector.Error as errorno:
            attemptcount += 1
            sdb.close()
            print errorno

    summonerids = []

    for summonerid in results:
        summonerids.append(summonerid[0])

    cursor.close()
    sdb.close()

    random.shuffle(summonerids)
    summonerids = summonerids[0:amount]

    return summonerids

print getsummonerids()


#from pymongo import MongoClient
#mdb = MongoClient()
