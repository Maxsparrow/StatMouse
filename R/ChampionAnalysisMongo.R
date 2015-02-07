library(RMongo)
library(jsonlite)
library(plyr)
source('~/StatMouse/R/SharedAssets.R')

makeparseddata<- function(championId,setlimit) {
    mongocon<-RMongo::mongoDbConnect('games',host='localhost',port=27017)
    
    query = paste0("{'championId':",championId,"}")
    rawgamespull<-RMongo::dbGetQuery(mongocon,"parsed",query,skip=0,limit=setlimit)
    
    gamedata<-data.frame()
    fullitemframe<-data.frame()
    
    ##Currently cost 973 seconds for 10000 games. I think the issue is we hit memory limits
    for(row in 1:nrow(rawgamespull)) {  
        itemlist<-fromJSON(rawgamespull$items[row])
        if(length(itemlist)==0) {
            next #if there are no items for this player, they were afk, so skip it
        }
        ##For now, only keep first item count of each item to make analysis simpler
        itemlist<-itemlist[grepl("_1$",names(itemlist))]
        
        newrow<-subset(rawgamespull[row,],select=c(-items,-X_id))
        gamedata<-rbind(gamedata,newrow)
        fullitemframe<-rbind.fill(fullitemframe,data.frame(itemlist))
    }
    
    ##Setting winner as a number factor, seems more intuitive
    gamedata$winner<-as.factor(as.numeric(as.logical(gamedata$winner)))

    champgames<-list(gamedata=gamedata,itemframe=fullitemframe)
    return(champgames)
}

addclusters <- function(champgames,numclusters=5) {
    champgames$itemframe[is.na(champgames$itemframe)]<-100
    
    fitcl<-kmeans(champgames$itemframe,numclusters)
    ##Consider trying dbscan. Had issues in first attempts
    #library(fpc)
    #fitcl<-dbscan(champgames$itemframe,nrow(champgames$itemframe)/6)
    
    champgames$gamedata$cluster <- fitcl$cluster
    champgames$itemframe$cluster <- fitcl$cluster
    return(champgames)
}
    
clusteranalysis<-function(champgames,method) {
    numclusters<-max(champgames$itemframe$cluster)
    ##TODO: Find a way to analyze clusters and pull out the most common holistic build, fairly difficult to assess
    
    buildorderframe<-data.frame()
    for(cluster in unique(champgames$itemframe$cluster)) {
        ##Medians method, has flaws, doesn't account for all orders and misses some items
        medians<-sapply(champgames$itemframe[champgames$itemframe$cluster==cluster,],median)
        #medians<-medians[medians<=20]
        
        orderframe<-data.frame()
        for(order in 0:99) {
            ordermedians<-medians[medians==order]
            ordermedians<-ordermedians[!grepl("cluster",names(ordermedians))]
            if(length(ordermedians)==0) next
            itemId<-substr(names(ordermedians),2,5)
            orderframe<-rbind(orderframe,data.frame(build=cluster,order=ifelse(order==0,0,max(orderframe$order)+1),itemId))
        }
        buildorderframe<-rbind(buildorderframe,orderframe)
    }
    
    if(!exists("itemtable")) {
        itemtable<-itemtablecreate()
        itemtable<<-itemtable
    }
    
    buildorderframe<-merge(buildorderframe,itemtable)
    buildorderframe<-buildorderframe[with(buildorderframe,order(build,order,itemId)),c("build","order","itemId","itemName")]    
    
    return(buildorderframe)
}

rankclusters<-function(champgames) {
    champgames$gamedata$cluster<-as.numeric(as.character(champgames$gamedata$cluster))
    champgames$gamedata$winner<-as.numeric(as.character(champgames$gamedata$winner))
    
    ##Pure winrate method, works pretty well
    clusterscores<-aggregate(winner~cluster,data=champgames$gamedata,mean)
    colnames(clusterscores)[2]<-"buildscore"    
    
    return(clusterscores)
}

analyzechampions <- function(championName) {    
    
    if(!exists("champtable")) {
        champtable<-champtablecreate()
        champtable<<-champtable
    }
    
    if(championName=="ALL") {
        championIds<-as.character(unique(champtable$champ_id))        
    } else {
        championIds<-champtable[champtable$champ_name==championName,"champ_id"]
    }
        
    allchamps<-data.frame()
    for(id in championIds) {
        champgames<-makeparseddata(id,1000)
        champgames<-addclusters(champgames,3)
        buildorderframe<-clusteranalysis(champgames)
        clusterscores<-rankclusters(champgames)
        
        ##Add cluster scores
        buildorderframe<-merge(buildorderframe,clusterscores,by.x="build",by.y="cluster")
        buildorderframe<-buildorderframe[order(-buildorderframe$buildscore),]
        
        buildorderframe<-cbind(championId=id,buildorderframe)
        championanalysis<-rbind(allchamps,buildorderframe)
    }
    
    return(championanalysis)
}