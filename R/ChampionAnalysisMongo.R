library(RMongo)

champion<-"Ezreal"
mongocon<-RMongo::mongoDbConnect('games',host='localhost',port=27017)
#query = c("{$match:{'participants.championId':81}}",
#          "{$limit:1}")
#champgames<-RMongo::dbAggregate(mongocon,"games",query)

query = "{'participants.championId':81}"
champgames<-RMongo::dbGetQuery(mongocon,"games",query,skip=0,limit=1)
