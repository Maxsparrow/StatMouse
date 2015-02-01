library(RMongo)
library(jsonlite)
library(plyr)
source('~/StatMouse/R/SharedAssets.R')

makeparseddata<- function(championId,setlimit) {
    mongocon<-RMongo::mongoDbConnect('games',host='localhost',port=27017)
    
    query = paste0("{'championId':",championId,"}")
    champgames<-RMongo::dbGetQuery(mongocon,"parsed",query,skip=0,limit=setlimit)
    
    newchampgames<-data.frame()
    
    ##Currently cost 973 seconds for 10000 games. I think the issue is we hit memory limits
    print(system.time({
    
        for(row in 1:nrow(champgames)) {  
            itemlist<-fromJSON(champgames$items[row])
            if(length(itemlist)==0) {
                next #if there are no items for this player, they were afk, so skip it
            }
            itemlist<-itemlist[!grepl("_1.|_2.|_3.|_4.|_5.|_6.|_7.|_8.|_9.",names(itemlist))]
            
            newrow<-data.frame(subset(champgames[row,],select=c(-items,-X_id)),itemlist)
            newchampgames<-rbind.fill(newchampgames,newrow)
        }
        
    }))

    return(newchampgames)
}

clusteranalysis <- function(newchampgames,numclusters=5) {
    
    itemset<-newchampgames[,grep("_",colnames(newchampgames))]
    itemset<-itemset[,!grepl("2003|2004",colnames(itemset))]
    itemset[is.na(itemset)]<-100  
    km<-kmeans(itemset,numclusters)
    clusterset<-itemset[km$cluster==1,]
    
    buildorderframe<-data.frame()
    for(cluster in 1:numclusters) {
        medians<-sapply(itemset[km$cluster==cluster,],median)
        medians<-medians[medians<=20]
        
        orderframe<-data.frame()
        for(order in 0:20) {
            ordermedians<-medians[medians==order]
            if(length(ordermedians)==0) next
            itemId<-substr(names(ordermedians),2,5)
            orderframe<-rbind(orderframe,data.frame(build=cluster,order,itemId))
        }
        buildorderframe<-rbind(buildorderframe,orderframe)
    }
    
    if(!exists("itemtable")) itemtable<-itemtablecreate()
    
    buildorderframe<-merge(buildorderframe,itemtable)
    buildorderframe<-buildorderframe[with(buildorderframe,order(build,order,itemId)),c("build","order","itemId","itemName")]    
    
    return(buildorderframe)
}