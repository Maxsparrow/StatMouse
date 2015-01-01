##Holds functions used by multiple scripts
##Set latest patch date below
#patchdate<<-as.Date("2014-11-20")
patchdate<<-as.Date("2014-12-11")

##Calls needed librarys for JSON conversion and SQL
library(jsonlite)
library(httr)   
library(RMySQL) 

reconnectdb <- function(database) {
    ##Finds all open MySQL connections and disconnects them, to make sure we don't have several open
    list<-DBI::dbListConnections(MySQL())
    for(i in list) {DBI::dbDisconnect(i)}
    
    ##Reconnects to the games database using username and password
    con<-try(DBI::dbConnect(MySQL(),host="siteground270.com",user="statmous_maxspar",password=dbpw,dbname=database))
    
    attemptcount<-0
    while(class(con)=="try-error") {
        print(paste("Could not connect to MySQL Server. It has been",(attemptcount*5),"minutes without connection. Waiting 5 minutes then trying again."))
        Sys.sleep(300)
        
        ##Try pulling again
        con<-try(DBI::dbConnect(MySQL(),host="siteground270.com",user="statmous_maxspar",password=dbpw,dbname=database))
        
        ##If we try 5 times (30 minutes) and we still have no response, end execution of the program
        if(attemptcount==5 & class(con)=="try-error") {
            stop("After retrying for 30 minutes, could not connect to server, ending execution")
        }
        
        attemptcount<-attemptcount+1
    }
    
    return(con)
}


champtablecreate <- function() {
    ##This function creates a champions table with all champion ids and champion names
    champtable <- data.frame()
    
    ##Calls api request for champions
    request <- "/api/lol/static-data/na/v1.2/champion"
    apidata<-apiquery(request,"champions",champtable)
    
    champions <- apidata[3][[1]]
    for (i in 1:length(champions)) {
        champinfo <- cbind(champions[[i]]$id,champions[[i]]$name)
        champtable <- rbind(champtable,champinfo)
    }
    
    colnames(champtable) <- c("champ_id","champ_name")
    
    return(champtable)
}

itemtablecreate <- function() {
    ##Creates a table with the list of item ids and names    
    itemtable <- data.frame()
    
    ##Calls api request for champions
    request <- "/api/lol/static-data/na/v1.2/item"
    apidata<-apiquery(request,"items",itemtable)
    
    items <- apidata$data
    for (i in 1:length(items)) {
        iteminfo <- cbind(items[[i]]$id,items[[i]]$name) ##Consider modifying data here to differentiate boots
        itemtable <- rbind(itemtable,iteminfo)
    }
    
    colnames(itemtable) <- c("itemId","itemName")
    
    ##Consider adding item?itemListData=all to the request above to get all the data, including gold cost and stats, you will need it later
    
    return(itemtable)     
}

##This function takes different request urls and queries the Riot API then sends the data back
apiquery <- function(request,requesttype = NA,objectcounter=0,dbtype="SQL") {
    ##Gets request code to paste into the API url
    
    ##Need to setup rate limit 500 req in 10 minutes, 10 req every 10 seconds, 8 requests per 10 seconds is conservative
    if(!exists("requestcount")) {requestcount <<- vector()}
    requestlimit <- 8
    timelimit <- 10
    
    ##First checks that there are more values than the rate limit. If the oldest value within the rate limit 
    ##is within the timelimit, then wait the amount of the timelimit before continuing. 
    numofrequests<-length(requestcount)
    if(numofrequests >= requestlimit) {
        if(requestcount[numofrequests-(requestlimit-1)]>(Sys.time()-timelimit)) {
            pauseforratelimit(timelimit,objectcounter,requesttype)
        }
    }
    
    ##Sets up code for requests and creates url for api
    apikey<-"0fb38d6c-f520-481e-ad6d-7ae773f90869"
    baseurl<-"https://na.api.pvp.net"
    if(grepl("[?]",request)) {
        endurl<-paste0("&api_key=",apikey)
    } else {
        endurl<-paste0("?api_key=",apikey)        
    }
    apiurl<-paste0(baseurl,request,endurl)
    
    ##Sends url to api and retrieves the data. This function checks for errors first
    data<-tryget(apiurl,requesttype,objectcounter)
    
    ##In case we pull in a different error code from the API, try again up to 5 times before giving up
    attemptcount<-0
    while(data$status_code!=200) {
        ##Output error messaging
        
        ##If we hit the rate limit status code, pause before retrying
        if(data$status_code==429) {
            print(paste0("Hit an error pulling API data; status code ",data$status_code,"; will pause for rate limit and retry"))
            pauseforratelimit(timelimit,objectcounter,requesttype)
        }
        
        if(data$status_code %in% c(400,401,403,404)) {
            print(paste0("Hit an error pulling API data; status code ",data$status_code,"; skipping this entry"))
            break
        }
        
        if(data$status_code %in% c(500,503)) {
            print(paste0("Hit an error pulling API data; status code ",data$status_code,"; waiting 5 minutes for server before retrying"))
            data<-waitforserver(apiurl,data,requesttype,objectcounter,attemptcount)
        }
        
        ##Try pulling data again
        data<-tryget(apiurl,requesttype,objectcounter)
    }
    
    ##Only try to convert data if it is a valid pull - must be status code 200 and contain data 
    ##Otherwise send back NA. Data can be empty if summonerId has no ranked games
    if(data$status_code==200 & length(content(data))!=0) {
        ##Convert API data to correct JSON format
        json1 <- toJSON(content(data))
        json2 <- jsonlite::fromJSON(json1)
        
        ##This is the data from the api sent back to other scripts
        if(dbtype=="SQL") {            
            apidata<-json2
        } else if(dbtype=="Mongo") {
            apidata<-json1
        }
    } else {
        apidata <- NA
    }    
    
    ##Removes old data in request count if older than one day ago and length of requestcount is longer than the limit
    if((requestcount[1] < (Sys.time()-60*60*24)) & numofrequests>requestlimit) {
        requestcount<-requestcount[(numofrequests-requestlimit):numofrequests]
        requestcount<<-requestcount
    }
    
    return(apidata)
}

tryget<-function(apiurl,requesttype,objectcounter) {
    ##Called by apiquery to check if we can connect to the server. If we get an error using GET 
    ##it will wait some time then try again
    data<-try(GET(apiurl))
    
    attemptcount<-0
    while(class(data)=="try-error") {
        data<-waitforserver(data,requesttype,objectcounter,attemptcount)
        data<-try(GET(apiurl))
    }
    
    ##Add the current time to the request count vector
    requestcount<-c(requestcount,Sys.time())
    requestcount<<-requestcount    
    
    return(data)
}

waitforserver<-function(apiurl,data,requesttype,objectcounter,attemptcount) {
    print(paste("Could not connect to API server. It has been",(attemptcount*5),"minutes without connection. Waiting 5 minutes then trying again."))
    Sys.sleep(300)
    
    ##If we try 5 times (30 minutes) and we still have no response, end execution of the program
    if(attemptcount==5 & class(data)=="try-error") {
        print("After retrying for 30 minutes, could not connect to server, ending execution")
        stop(endfunction(requesttype,objectcounter))
    } else if (class(data)!="try-error") return(data)
}

pauseforratelimit<-function(timelimit,objectcounter,requesttype) {
    ##Pauses execution of apiquery function until time has passed for the ratelimit to subside
    print(sprintf("pause %g seconds for rate limit, currently have %g %s",timelimit,objectcounter,requesttype))
    Sys.sleep(timelimit)    
}