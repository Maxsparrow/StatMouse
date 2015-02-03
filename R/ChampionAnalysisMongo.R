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
        ##Remove itemcounts over 10
        itemlist<-itemlist[!grepl("_1.|_2.|_3.|_4.|_5.|_6.|_7.|_8.|_9.",names(itemlist))]
        
        newrow<-subset(rawgamespull[row,],select=c(-items,-X_id))
        gamedata<-rbind(gamedata,newrow)
        fullitemframe<-rbind.fill(fullitemframe,data.frame(itemlist))
    }

    champgames<-list(gamedata=gamedata,itemframe=fullitemframe)
    return(champgames)
}

addclusters <- function(champgames,numclusters=5) {
    
    ##Remove potions and biscuits since they mess things up
    champgames$itemframe<-champgames$itemframe[,!grepl("2003|2004|2010",colnames(champgames$itemframe))]
    champgames$itemframe[is.na(champgames$itemframe)]<-100
    
    fitcl<-kmeans(champgames$itemframe,numclusters)
    
    champgames$gamedata$cluster <- fitcl$cluster
    champgames$itemframe$cluster <- fitcl$cluster
    return(champgames)
}
    
clusteranalysis<-function(champgames) {
    numclusters<-max(champgames$itemframe$cluster)
    
    buildorderframe<-data.frame()
    for(cluster in 1:numclusters) {
        medians<-sapply(champgames$itemframe[champgames$itemframe$cluster==cluster,],median)
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
    
    if(!exists("itemtable")) {
        source('./StatMouse/R/SharedAssets.R')
        itemtable<-itemtablecreate()
        itemtable<<-itemtable
    }
    
    buildorderframe<-merge(buildorderframe,itemtable)
    buildorderframe<-buildorderframe[with(buildorderframe,order(build,order,itemId)),c("build","order","itemId","itemName")]    
    
    return(buildorderframe)
}

rankclusters<-function(champgames) {
    library(caret)
    champgames$gamedata$winner<-as.factor(as.numeric(as.logical(champgames$gamedata$winner)))
    champgames$gamedata$cluster<-as.factor(as.character(champgames$gamedata$cluster))
    formula<-as.formula("winner~teamPercGold+playerPercGold+teamBaronKills+teamDragonKills+
                            teamTowerKills+matchDuration+gameTowerKills+KDA+cluster-1")
    
#     ##base method
#     model<-glm(formula,data=champgames$gamedata,family=binomial)
#     imp<-round(coef(model),6)
#     modelsummary<-data.frame(importance=imp,variable=names(imp))
    
    ##Caret Method
    model<-train(formula,data=champgames$gamedata,method='glm')
    imp<-varImp(model,scale=FALSE,usemodel=FALSE)
    modelsummary<-data.frame(importance=round(imp$importance,6),variable=row.names(imp$importance))
    
    modelsummary<-modelsummary[order(-modelsummary[,1]),]

    ##Check to make sure cluster5 isn't already in the names
    if(sum(grepl("cluster5",modelsummary$variable))>0) {stop("relevel cluster factors, cluster5 should be last")}
    ##Create cluster ranks and add cluster5 as 0
    clusterranks<-data.frame(cluster=gsub("cluster","",c(as.character(modelsummary[grepl("cluster",modelsummary$variable),"variable"]),
                                                         "cluster5")),rank=c(1,2,3,4,5))
    
    return(clusterranks)
}

runallchampions <- function() {    
    champtable<-champtablecreate()
    championIds<-as.character(unique(champtable$champ_id))
        
    allchamps<-data.frame()
    for(id in championIds[1:2]) {
        champgames<-makeparseddata(id,1000)
        champgames<-addclusters(champgames)
        buildorderframe<-clusteranalysis(champgames)
        clusterranks<-rankclusters(champgames)
        
        ##Add cluster ranks
        buildorderframe<-merge(buildorderframe,clusterranks,by.x="build",by.y="cluster")
        ##Remove old 'buildcluster' id before adding to db, just change to buildrank
        buildorderframe$buildrank<-buildorderframe$rank
        buildorderframe<-buildorderframe[c("buildrank","order","itemId","itemName")]
        buildorderframe<-buildorderframe[order(buildorderframe$buildrank),]
        
        buildorderframe<-cbind(championId=id,buildorderframe)
        allchamps<-rbind(allchamps,buildorderframe)
    }
    
    return(allchamps)
}