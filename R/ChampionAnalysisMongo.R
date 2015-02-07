library(RMongo)
library(jsonlite)
library(plyr)
source('~/StatMouse/R/SharedAssets.R')

makeparseddata<- function(championId,setlimit) {
    mongocon<-RMongo::mongoDbConnect('games',host='localhost',port=27017)
    
    query = paste0("{'championId':",championId,"}")
    rawgamespull<-RMongo::dbGetQuery(mongocon,"parsed",query,skip=0,limit=setlimit)
    
    gamedata<-data.frame()
    itemframe<-data.frame()
    
    ##Currently cost 973 seconds for 10000 games. I think the issue is we hit memory limits
    for(row in 1:nrow(rawgamespull)) {  
        itemlist<-fromJSON(rawgamespull$items[row])
        if(length(itemlist)==0) {
            next #if there are no items for this player, they were afk, so skip it
        }
        ##For now, only keep first item count of each item to make analysis simpler
        itemlist<-itemlist[grepl("_1$",names(itemlist))]
        
        itemcomboframe<-data.frame()
        ##Reinventing this so that it shows item combinations for each order, so the orders are the columns, not the items
        for(order in 0:30) {
            itemcombo<-vector()
            ##Find the itemIds that match the order we are on
            for(itemnum in 1:length(itemlist)) {
                if(itemlist[itemnum]==order) {
                    itemcombo<-c(itemcombo,names(itemlist[itemnum]))
                }
            }
            ##If there are any for this order, convert them and paste them together
            ##Add them with the order to a data frame
            if(length(itemcombo)!=0){
                itemcombo<-substr(itemcombo,1,4)
                itemcombo<-itemcombo[order(itemcombo)]
                itemcombo<-paste0(itemcombo,collapse=";")
                itemcomboframe<-rbind(itemcomboframe,data.frame(order,itemcombo))    
            }
        }
        ##Transform the data frame we just got so the orders are the column names
        itemcombos<-as.character(itemcomboframe$itemcombo)
        itemcombos<-data.frame(t(itemcombos))
        names(itemcombos)<-itemcomboframe$order
        
        ##Add this row's game data to full game data frame
        newrow<-subset(rawgamespull[row,],select=c(-items,-X_id))
        newrow<-cbind(newrow,itemcombos)
        gamedata<-rbind.fill(gamedata,newrow)
        
        ##Add this row's items to a separate itemframe for clustering
        itemframe<-rbind.fill(itemframe,data.frame(itemlist))
    }
    
    ##Setting winner as a number factor, seems more intuitive
    gamedata$winner<-as.factor(as.numeric(as.logical(gamedata$winner)))
    champgames<-list(gamedata=gamedata,itemframe=itemframe)
    return(champgames)
}

addclusters <- function(champgames,numclusters=3) {
    champgames$itemframe[is.na(champgames$itemframe)]<-100
    fitcl<-kmeans(champgames$itemframe,numclusters)
    ##Consider trying dbscan. Had issues in first attempts
    #library(fpc)
    #fitcl<-dbscan(champgames$itemframe,nrow(champgames$itemframe)/6)
    
    champgames$gamedata$cluster <- fitcl$cluster
    champgames$itemframe$cluster <- fitcl$cluster
    return(champgames)
}
    
##Don't want to use this anymore
clusteranalysismedians<-function(champgames) {
    numclusters<-max(champgames$itemframe$cluster)
    ##TODO: Find a way to analyze clusters and pull out the most common holistic build, fairly difficult to assess
    ##On to something with the medians method. Perhaps I need to just find a way to include higher order, late game items
    ##Maybe if I loop through all the orders, find the most frequent items for each order over 10%, remove duplicates as we go along
    
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
    
    ##Unique order item freq method
    ##NEED TO TEST THIS
    cluster=1
    clusterset<-champgames$itemframe[champgames$itemframe$cluster==1,]
    fullorderframe<-data.frame()
    for (order in 0:20) {
        ordercounts<-sapply(clusterset,function(x) sum(x==order))
        orderperc<-ordercounts/sum(ordercounts)
        orderperc<-orderperc[!names(orderperc) %in% fullorderframe]
        filterorderperc<-orderperc[orderperc>0.1]
        orderperctouse<-ifelse(length(filterorderperc)==0,head(orderperc[order(-orderperc)],3),filterorderperc)
        orderframe<-data.frame(order,orderperctouse,itemId=names(filterorderperc))
        fullorderframe <- rbind(fullorderframe,orderframe)
    }
    
    if(!exists("itemtable")) {
        itemtable<-itemtablecreate()
        itemtable<<-itemtable
    }
    
    buildorderframe<-merge(buildorderframe,itemtable)
    buildorderframe<-buildorderframe[with(buildorderframe,order(build,order,itemId)),c("build","order","itemId","itemName")]    
    
    return(buildorderframe)
}

clusteranalysiscombos<-function(champgames) {
    clusterset<-champgames$gamedata[champgames$gamedata$cluster==1,]
    n<-nrow(clusterset)
    for(col in 17:ncol(clusterset)) {
        comboperc<-table(clusterset[,col])/n
        comboperc<-head(comboperc[order(-comboperc)])
        print(paste0("Order",colnames(clusterset[col])))
        print(comboperc)
    }
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
        buildorderframe<-clusteranalysismedians(champgames)
        clusterscores<-rankclusters(champgames)
        
        ##Add cluster scores
        buildorderframe<-merge(buildorderframe,clusterscores,by.x="build",by.y="cluster")
        buildorderframe<-buildorderframe[order(-buildorderframe$buildscore),]
        
        buildorderframe<-cbind(championId=id,buildorderframe)
        championanalysis<-rbind(allchamps,buildorderframe)
    }
    
    return(championanalysis)
}
