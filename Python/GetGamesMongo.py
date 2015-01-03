import pymysql
import random
from Connections import *

def getsummonerids(amount=10):

    sdb = pymysql.connect(host=SQLhost,user=SQLuser,passwd=SQLpass,db="statmous_gamedata")
    cursor = sdb.cursor()

    query = ("SELECT summonerId FROM summoners")

    cursor.execute(query)

    results = cursor.fetchall()

    summonerids = []

    for summonerid in results:
        summonerids.append(summonerid[0])

    cursor.close()
    sdb.close()

    random.shuffle(summonerids)
    summonerids = summonerids[0:amount]

    return summonerids

def apirequest(requesttype,summonerid=NA):
    url = {
        'matchhistory'
        
    

def getgames(amount=10):
    return False

summonerids = getsummonerids()



#from pymongo import MongoClient
#mdb = MongoClient()


