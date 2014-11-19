## This function pulls summonerIds from summoner names
## Not in use right now because we aren't adding summonerids at the moment.
addsummonerids <- function(summonernames,requesttype="summonerids",requestitem=vector()) {
    ##create summonerids vector
    tempsummonerids <- vector()
    
    ##Set names to lowercase and remove spaces. Also only keep ASCII character names
    summonernames<-tolower(summonernames)
    summonernames<-gsub(" ","",summonernames)
    summonernames<-iconv(unlist(summonernames),"latin1","ASCII")
    summonernames<-summonernames[!is.na(summonernames)]
    
    ##If there are no non-NA summonernames left, return NA
    if (length(summonernames)==0) {
        tempsummonerids<-NA   
    } else {        
        ##Pulls summonerids for each summonername in list
        for (k in 1:length(summonernames)) {
            request <- paste("/api/lol/na/v1.4/summoner/by-name/",summonernames[k],sep="")        
                        
            ##Try to query summonerid and add it to the list
            if(length(requestitem)==0) {requestitem<-tempsummonerids}
            apidata<-apiquery(request,requesttype,requestitem)
            ##Check if the apidata is bad and skip if so
            if(is.na(apidata[1]) | is.null(unlist(apidata[1]))) {next}
            ##Add new summoner id to the list of summonerids
            tempsummonerids[k] <- apidata[[1]]$id
        }
        
        tempsummonerids<-tempsummonerids[!is.na(tempsummonerids)]        
    }
    
    ##Return the new summonerids
    return(tempsummonerids)
}