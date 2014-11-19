getgames<-function(summonerids=NA,limit=50000) {
    ##Takes summonerids as a vector, if you pass it nothing it will use 'summonerids 1.csv' 
    ##from the working directory to create the summonerids vector
    ##Current runtimes:
    ##9/25: 6426.14 seconds for 3000 games
    ##Avg time per game (10 rows) 9/25: 2.14 seconds
    ##11/13; After switching to SQL: 2765.70 seconds for 1000 games
    ##Avg time per game (10 rows) 11/13: 2.77 seconds
    
    ##Load needed functions from other file
    source('D:/The Internet/My Documents/Dropbox/My Documents/Riot API/SharedAssets.R')
    
    ##Connect to database
    con<-reconnectdb("statmous_gamedata")    
    
    ##Read in cached summonerIds file and skip the first row which is just a blank column header
    summonerids<-dbGetQuery(con,'SELECT summonerId FROM statmous_gamedata.summoners;')[,1]
    
    ##Find any previous matches within the past week, so when we pull new matches from the past week, we check that they aren't duplicates
    datelimit<-format(Sys.time()-60*60*24*7,"%Y-%m-%d")
    previousmatches<-dbGetQuery(con,paste0("SELECT matchId FROM statmous_gamedata.games WHERE createDate >= '",datelimit,"';"))
    previousmatches<-as.numeric(previousmatches[,1])
    dbDisconnect(con)
        
    ##Rearrange summonerids so we pull them in random order
    ##And remove extra summonerids since we don't need to use quite so many
    summonerids<-sample(summonerids,limit)
    
    ##Create data frame for later if it doesn't exist already
    if(!exists("games")) {games<-data.frame()}
    
    ##Create table with all the champions
    champtable<-champtablecreate()
    
    c<-0
    while (nrow(games)/10<limit) {
        c<-c+1
              
        currentsummoner<-summonerids[c]
        
        ##Use summonerId to pull past 10 games (max currently available)
        request <- paste("/api/lol/na/v2.2/matchhistory/",currentsummoner,sep="")
        apidata<-apiquery(request,"games",games)  
        ##Error handling code. If something is pulled back wrong this should skip to next 
        ##Mainly, here this skips summonerIds with no Ranked Games
        if(is.na(apidata[1])) {next} ##Error catching
        
        ##Filter for only Ranked solo queue matches
        matches<-apidata$matches    
        matches<-matches[matches$queueType=="RANKED_SOLO_5x5",]
            
        ##Convert createDate to Date format
        fun <- function(x) as.Date(x/ 86400000, origin = "1970-01-01")
        matches$matchCreation<-sapply(matches$matchCreation,fun)
        class(matches$matchCreation)<-"Date"
        
        ##Filter for only games within the past 7 days
        datelimit<-as.Date(Sys.time()-60*60*24*7,origin="1970-01-01")
        matches<-matches[matches$matchCreation>=datelimit,]
        
        ##Find list of matchIds
        matchIds<-unlist(matches$matchId)
        
        ##Remove matchIds we've already queried
        matchIds<-matchIds[!matchIds %in% games$matchId]
        matchIds<-matchIds[!matchIds %in% previousmatches]
        
        if(length(matchIds)==0) {next} ##skip to next summonerid if no matchIds meeting criteria are found
        
        for (j in 1:length(matchIds)) {
            gamedata<-creategamedata2(matchIds[j],"games",games,champtable)
            if(gamedata[1,2]==0) {next} ##Conditional that allows for skipping games on errors
            
            result<-addtodb(gamedata)
            
            ##Add gamedata to the main games data frame
            games<-rbind(games,gamedata)
        }
    }
    
    endfunction("games",games) 
}

creategamedata2 <- function(matchId,requesttype,requestitem,champtable) {
    ##Takes a match Id and pulls the game info for it
    
    ##Use matchId to pull the game info
    request <- paste("/api/lol/na/v2.2/match/",matchId,sep="")
    apidata<-apiquery(request,requesttype,requestitem)    
    ##If the data pulled back by the request is bad, create an all 0s matrix
    ##in the main function, this result is skipped
    if(is.na(apidata[1])) {return(matrix(rep(0,100),10))} ##Error catching - should only happen after displaying status code errors
    
    ##Save participants and stats into data frames
    gamedata<-apidata$participants
    stats<-apidata$participants$stats
    
    ##only pulls in needed columns (adding summoner spells would be an easy extension to this)
    validcolumns <- c("participantId","teamId","championId")                      
    gamedata <- gamedata[validcolumns]  
    
    ##Filter stats for only needed columns
    validcolumns <- c("winner","goldEarned","item0","item1","item2","item3","item4","item5","item6")
    stats <- stats[validcolumns]
    
    ##Checks if any columns are missing because of null values, if so, adds NULLs 
    ##for each missing column and adjusts the column name
    missingcol<-setdiff(validcolumns,colnames(stats))
    if(length(missingcol)>0) {
        for (i in 1:length(missingcol)) {
            stats<-cbind(stats,rep(0,nrow(stats)))
            colnames(stats)[ncol(stats)]<-missingcol[i]
        }        
    }   
    
    ##Finds the item columns and changes any NULL values into 0s
    itemcols<-grep("item",colnames(stats))
    for (k in itemcols[1]:itemcols[length(itemcols)]) {
        stats[stats[,k]=="NULL",k]<-"0"
    }
    
    ##Adds the updated stats table back to the data frame
    gamedata<-cbind(gamedata,stats)
    
    ##change columns in gamedata data frame out of list format
    for (k in 1:ncol(gamedata)) {
        gamedata[,k]<-unlist(gamedata[,k])
    }
    
    ##Add createDate to the game data
    createDate<-apidata$matchCreation 
    gamedata<-cbind(createDate,gamedata)
    
    ##Add matchId to the game data
    gamedata<-cbind(matchId,gamedata)
    colnames(gamedata)[1]<-"matchId"
    
    ##Adds summoner names
    summonernames<-unlist(apidata$participantIdentities$player$summonerName)
    gamedata<-cbind(summonernames,gamedata)
    
    ##Adds summonerIds as NAs for now, will fix later. Changes column names
    gamedata<-cbind(NA,gamedata)    
    colnames(gamedata)[1:2]<-c("summonerId","summonerName")
    
    ##Convert createDate to Date format
    fun <- function(x) as.Date(x/ 86400000, origin = "1970-01-01")
    gamedata$createDate<-sapply(gamedata$createDate,fun)
    class(gamedata$createDate)<-"Date"
    
    ##Adds % of gold earned for each team
    totalgold<-sum(gamedata$goldEarned)
    ##Make a table with each team's gold as a percentage of the total gold
    teamgolds<-rbind(c(100,round(sum(gamedata[gamedata$teamId==100,"goldEarned"])/totalgold,4)),
          c(200,round(sum(gamedata[gamedata$teamId==200,"goldEarned"])/totalgold,4)))
    ##Merge gamedata with the above table
    gamedata<-merge(gamedata,teamgolds,by.x="teamId",by.y=1)
    ##Set new column's name
    colnames(gamedata)[ncol(gamedata)]<-"teamPercGold"
    
    ##Adds % of gold earned for each player
    gamedata$playerPercGold<-0    
    ##loop through each player and find the percentage of gold earned and add it to new column
    for (i in 1:nrow(gamedata)) {
        gamedata$playerPercGold[i]<-round(gamedata$goldEarned[i]/totalgold,4)    
    }
    
    ##Adds champion names to the table
    gamedata<-merge(gamedata,champtable,by.x="championId",by.y="champ_id")
    colnames(gamedata)[ncol(gamedata)]<-"championName"
    
    ##Resort the column names in the format that I Want. and put it back in order the way it was before the merge
    gamedata<-gamedata[c("summonerId","summonerName","matchId","createDate","participantId","teamId","championId","championName","winner",
               "goldEarned","playerPercGold","teamPercGold","item0","item1","item2","item3","item4","item5","item6")]
    gamedata<-gamedata[order(gamedata$participantId),]
    
    ##Set winner as binary numeric
    gamedata$winner<-as.numeric(gamedata$winner)
        
    return(gamedata)
}

tryget<-function(apiurl,requesttype,requestitem) {
    ##Called by apiquery to check if we can connect to the server. If we get an error using GET 
    ##it will wait some time then try again
    data<-try(GET(apiurl))
    
    attemptcount<-0
    while(class(data)=="try-error") {
        print(paste("Could not connect to API server. It has been",(attemptcount*5),"minutes without connection. Waiting 5 minutes then trying again."))
        Sys.sleep(300)
        
        ##Try pulling again
        data<-try(GET(apiurl))
        
        ##If we try 5 times (30 minutes) and we still have no response, end execution of the program
        if(attemptcount==5 & class(data)=="try-error") {
            print("After retrying for 30 minutes, could not connect to server, ending execution")
            endfunction(games,requesttype,requestitem)
        }
        
        attemptcount<-attemptcount+1
    }
        
    ##Add the current time to the request count vector
    requestcount<-c(requestcount,Sys.time())
    requestcount<<-requestcount    
    
    return(data)
}

pauseforratelimit<-function(timelimit,requesttypecount,requesttype) {
    ##Pauses execution of apiquery function until time has passed for the ratelimit to subside
    print(sprintf("pause %d seconds for rate limit, currently have %d %s",timelimit,requesttypecount,requesttype))
    Sys.sleep(timelimit)    
}

addtodb <- function(gamedata) {
    ##Adds the current gamedata to the MySQL database
    con<-reconnectdb("statmous_gamedata")
    
    result<-FALSE
    trycount<-0
    while(result!=TRUE) {        
        result<-try(dbWriteTable(con,'games',gamedata,append=TRUE,row.names=FALSE))
        
        trycount<-trycount+1
        if(result!=TRUE & trycount<5) {
            print("Write failed, trying again after 5 minutes")
            Sys.sleep(300)
        } else if(result!=TRUE & trycount==5) {
            print("After 5 attempts, skipping this entry")
            break
        } else {
            print("Successfully wrote game to database")
        }                
    }
    
    dbDisconnect(con)
    return(result)    
}

endfunction <- function(requesttype="NA",games) {
    ##Ends the function execution after hitting the limit or losing internet connection for 30 minutes
    ##Only save to csv if this function is called with the games variable. Otherwise output an error
    if(requesttype=="games") {
        ##Write csv file with just today's games that we got
        todaydt<-format(Sys.time(),"%m.%d.%y")
        write.csv(games,paste0("finalgames ",todaydt,".csv"),row.names=FALSE)  
                
        ##Output the number of games we saved and the final count on MasterFinalGames
        gamesrows<-nrow(games)
        outputmessage<-paste(gamesrows,"games added to MySQL database")
        return(outputmessage)
    } else {
        stop("Error: Endtype is not games")
    }    
}