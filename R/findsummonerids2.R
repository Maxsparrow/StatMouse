findsummonerids2 <- function(summonerids,limit = 100000) {
    ##Finds a large number of summonerids and saves them to a csv file so that we can use them in the future
    
    ##Get current summonerids from server
    con<-reconnectdb("statmous_gamedata")    
    summonerids<-dbGetQuery(con,"SELECT summonerId FROM summoners;")
    dbDisconnect(con)
    
    summonerids<-as.character(summonerids[,1])
        
    ##Set limit to the amount requested plus the amount already passed in, so we get 100,000 more by default
    limit = limit + length(summonerids)
    
    ##loops until it reaches at least the desired # of summoner ids
    counter<-1
    while (length(summonerids) <= limit) {
        cursummoner<-summonerids[counter]
        if(is.na(cursummoner)) {
            print("Error: NA summonerId")
            next
        }
        
        ##prepares tempid variable for later
        newids <- vector()
        
        ##pulls recent games and finds summonerids
        request <- paste("/api/lol/na/v1.3/game/by-summoner/",cursummoner,"/recent",sep="")
        apidata<-apiquery(request,"summonerids",length(summonerids))
        if(is.na(apidata[1])) {next}
        
        ##Finds other players and adds them to a dataframe
        fellowPlayers <- apidata$games$fellowPlayers
        for (i in 1:length(fellowPlayers)) {
            newids <- c(newids,unlist(fellowPlayers[[i]][,1]))
        }
        
        ##Removes summoner ids we already got before
        newids<-newids[!newids %in% summonerids]     
        
        ##Add to current list of all summonerids
        summonerids<-c(summonerids,newids)
        
        ##If there are new ids to add, convert them to a data frame and add them to the database
        if(length(newids)!=0) {        
            newids<-data.frame(newids)
            colnames(newids)<-"summonerId"
            result<-addtodb(newids,"summoners")
        }
        
        counter<-counter+1
        
        if(counter>length(summonerids)) {
            print("Ending Execution: Ran out of summonerIds to query")
            break
        }
    }
    
    return(summonerids)
}