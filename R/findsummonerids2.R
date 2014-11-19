findsummonerids2 <- function(summonerids,limit = 100000) {
    ##Finds a large number of summonerids and saves them to a csv file so that we can use them in the future
    
    ##converts summonerids to data frame if not already
    if(class(summonerids)=="data.frame") {
        summonerids<-as.vector(summonerids[,1])
    } else if (class(summonerids)=="list") {
        summonerids<-unlist(summonerids)
    }
    
    ##loops until it reaches at least the desired # of summoner ids
    counter<-1
    while (length(summonerids) <= limit) {
        cursummoner<-summonerids[counter]
        if(is.na(cursummoner)) {
            print("Error: NA summonerId")
            next
        }
        
        ##prepares tempid variable for later
        tempids <- vector()
        
        ##pulls recent games and finds summonerids
        request <- paste("/api/lol/na/v1.3/game/by-summoner/",cursummoner,"/recent",sep="")
        apidata<-apiquery(request,"summonerids",summonerids)
        if(is.na(apidata[1])) {next}
        
        ##Finds other players and adds them to a dataframe
        fellowPlayers <- apidata$games$fellowPlayers
        for (i in 1:length(fellowPlayers)) {
            tempids <- c(tempids,unlist(fellowPlayers[[i]][,1]))
        }
        
        ##Adds the new players to the main list of summoner ids
        summonerids <- c(summonerids,tempids)        
        summonerids <- unique(summonerids)
        
        counter<-counter+1
        
        if(counter>length(summonerids)) {
            print("Ending Execution: Ran out of summonerIds to query")
            break
        }
    }
    
    filelist<-list.files()
    cnt<-length(grep("summonerids",filelist))+1
    write.csv(summonerids,paste0("summonerids ",cnt,".csv"),row.names=FALSE)
}