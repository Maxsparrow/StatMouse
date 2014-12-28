import mysql.connector
from Connections import *

sdb = mysql.connector.connect(host=SQLhost,user=SQLuser,passwd=SQLpass,db="statmous_gamedata")

def getsummonerids(amount):
    return False

#from pymongo import MongoClient
#mdb = MongoClient()
