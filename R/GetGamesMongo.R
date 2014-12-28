library(RMongo)

getgamesmongo <- function(limit=1000) {
    ##Load needed functions from other file
    source('./StatMouse/R/SharedAssets.R')
    
    ##Connect to database
    con<-reconnectdb("statmous_gamedata") 
    
    summonerids<-buildsummonerlist(limit*3)
    
    runcounter<-0
    gamecounter<-0
    while (gamecounter<limit) {
        runcounter<-runcounter+1
        
        currentsummoner<-summonerids[runcounter]
        
        ##Check if we ran out of summonerids due to not pulling enough in, if so end execution
        if(runcounter>length(summonerids)) {
            print("Ending execution, ran out of summonerids")
            stop(endmongo(runcounter))
        }
        
        ##Use summonerId to pull past 10 games (max currently available)
        request <- paste("/api/lol/na/v2.2/matchhistory/",currentsummoner,sep="")
        apidata<-apiquery(request,"games",gamecounter)  
        ##Error handling code. If something is pulled back wrong this should skip to next 
        ##Mainly, here this skips summonerIds with no Ranked Games
        if(is.na(apidata[1])) {next} ##Error catching   
        
        ##Filter for only Ranked solo queue matches
        matches<-apidata$matches    
        matches<-matches[matches$queueType=="RANKED_SOLO_5x5",]
        
        ##Convert createDate to Date format
        datefun <- function(x) as.Date(x/ 86400000, origin = "1970-01-01")
        matches$matchCreation<-sapply(matches$matchCreation,datefun)
        class(matches$matchCreation)<-"Date"
        
        ##Filter for only games since the last patch
        matches<-matches[matches$matchCreation>=patchdate,]
        
        ##Find list of matchIds
        matchIds<-unlist(matches$matchId)
        
        if(length(matchIds)==0) {next} ##skip to next summonerid if no matchIds meeting criteria are found
        
        for (j in 1:length(matchIds)) {            
            ##Connecto mongodb
            mongocon<-mongoconnect("games")
            
            ##Check to see if this matchId already exists in database, if so skip
            previousmatch<-RMongo::dbGetQuery(mongocon, 'games', paste0("{'matchId': [",matchIds[j],"]}"))
            
            if(NROW(previousmatch)!=0) {print("this game already exists in DB, skipping to next");next}
            
            ##Get game data for mongodb
            gamedata<-creategamedatamongo(matchIds[j],gamecounter)
            if(is.na(gamedata[1])) {next} ##Error catching 
            
            ##Add to mongo database
            test<-RMongo::dbInsertDocument(mongocon,'games',as.character(gamedata))
            
            RMongo::dbDisconnect(mongocon)
            
            if(test=="ok") {
                print("Successfully added game to mongoDB")
            } else {
                print("Had error loading game into mongoDB")
            }
            
            rm(gamedata)
            
            gamecounter<-gamecounter+1
        }
    }
    
    print(endmongo(gamecounter))
}

buildsummonerlist<-function(amount) { 
    con<-reconnectdb("statmous_gamedata")
    
    ##Read in cached summonerIds from database as a vector
    summonerids<-DBI::dbGetQuery(con,'SELECT summonerId FROM statmous_gamedata.summoners;')[,1]
    
    ##Rearrange summonerids so we pull them in random order
    ##And remove extra summonerids since we don't need to use quite so many
    summonerids<-sample(summonerids,amount)
    
    return(summonerids)
}

creategamedatamongo<- function(matchId,objectcounter) {
    request<-paste0("/api/lol/na/v2.2/match/",matchId,"?includeTimeline=true")
    apidata<-apiquery(request,"games",objectcounter,"Mongo")    
    return(apidata)
}

mongoconnect<-function(database) {
    mongocon<-mongoDbConnect(database,"localhost",27017)
    return(mongocon)
}

endmongo <- function(gamecounter) {
    ##Output the number of games we saved and the final count on MasterFinalGames
    outputmessage<-paste(gamecounter,"games added to local Mongo database")
    return(outputmessage)
}