createmodel <- function(champlist="ALL") {
    ##Also, consider doing a k-nearest neighbor classification based on item builds
    ##Then you can do a regression analysis on each 'group' created by knn and list the items in 
    ##the best 1 or 2 groups. This seems like the best idea.
    
    if(champlist=="ALL") {
        champtable<-champtablecreate()
        champlist<-unique(champtable$champ_name)
        champlist<-gsub("'","''",champlist)
    }
    
    allchamps<-data.frame()
    for(champion in champlist) {
        
        ##Call custom function below to convert data frame to wide format
        widedata<-makewidedata(champion) 
        
        ##Print progress report
        numgames<-nrow(widedata)
        print(sprintf("Analyzing %s",champion))
        print(sprintf("Based on %g games",numgames))
        
        ##Split into training set and test set
        splits<-splitdf(widedata,1234)
        trainset<-splits$trainset
        testset<-splits$testset
        
        ##Fit model with items, teamahead, fedplayer and no intercept, NOT binomial, has best performance 96% accurate
        fit<-glm("winner~.-1",data=trainset)
        
        ##Output tests of the model showing how accurate it is
        measuremodel(fit,testset)
        
        ##Call function to summarize the fit and create itempower for each item
        modelsummary<-summarizemodel(fit,trainset)
        
        ##Print this to see the results as we load it
        print(modelsummary)
        
        ##Add the date the analysis was run and champion name to our model data
        todaydt<-Sys.time()
        modelsummary<-cbind(todaydt,champion,modelsummary)
        colnames(modelsummary)[1:2]<-c("analysisDate","championName")
                
        ##Add this champion to the list of all champions
        allchamps<-rbind(modelsummary,allchamps)
    }
    
    return(allchamps)
}

makewidedata<-function(champion) {  
    ##Load needed functions from other file and needed libraries
    source('./StatMouse/R/SharedAssets.R')   
    library(reshape2)
    
    con<-reconnectdb("statmous_gamedata")
    
    ##Keep matchId so we get a unique identifier
    champgames<-dbGetQuery(con,paste0("SELECT matchId,winner,teamPercGold,playerPercGold,item0,item1,item2,item3,item4,item5,item6
                                      FROM statmous_gamedata.games WHERE championName='",champion,"';"))
    champgames<-unique(champgames)
        
    ##Set item variables as character class
    itemcols<-grep("item",colnames(champgames))
    for (i in itemcols) {
        champgames[,i]<-as.character(champgames[,i])
    }    
    
    ##Experiment with these two variables and see if they give better linear regression results - i like these so far
    champgames$teamahead<-0
    champgames[champgames$teamPercGold>0.50,"teamahead"]<-1   
    champgames$fedplayer<-0
    champgames[champgames$playerPercGold>0.12,"fedplayer"]<-1 
    
    ##Set variables to keep as static vars
    idvars<-c("matchId","winner","teamPercGold","playerPercGold","teamahead","fedplayer")
    
    ##Melt data frame
    long.champgames<-melt(champgames,id.vars=idvars)  
    
    ##Create a concatenation of the id variables with plus signs to use in dcast
    idsum<-paste(idvars,collapse=" + ")
    
    ##recast the data adding up the count of each item for each match/summoner
    #widedata<-dcast(long.champgames,paste(idsum,"value",sep="~"),length,fill=0)  ##Makes each item variable a count (can be more than 1 of an item)
    widedata<-dcast(long.champgames,paste(idsum,"value",sep="~"),function(x) 1,fill=0)   ##Makes each item variable binary based on whether it exists
    
    ##Cut out the '0' column indicating missing items
    zerocol<-grep("^[0]$",colnames(widedata))
    widedata<-widedata[,-zerocol]
    
    ##Remove matchId,teamPercGold, and playerPercGold because we won't need them anymore
    unneededcols<-c("matchId","teamPercGold","playerPercGold")
    for(colname in unneededcols) {
        colnum<-grep(colname,colnames(widedata))
        widedata<-widedata[,-colnum]
    }
    
    ##add 'item' before each item column
    itemcolstart<-grep("1",colnames(widedata))[1]
    for (i in itemcolstart:ncol(widedata)) {
        colnames(widedata)[i]<-paste0("item",colnames(widedata)[i])
    }
    
    return(widedata)
}

splitdf <- function(dataframe, seed=NULL) {
    if (!is.null(seed)) set.seed(seed)
    index <- 1:nrow(dataframe)
    trainindex <- sample(index, trunc(length(index)/2))
    trainset <- dataframe[trainindex, ]
    testset <- dataframe[-trainindex, ]
    list(trainset=trainset,testset=testset)
}

measuremodel<-function(model,testset) {
    ##Input a fit or model from glm and a testset
    n<-nrow(testset)
    
    pred<-predict(model,testset[,-1],type="response")
    
    predbin<-pred
    predbin[predbin<0.5]<-0
    predbin[predbin>=0.5]<-1
    
    predtable<-table(predbin,testset[,1])
    print(predtable)
    perccorrect<-(predtable[1,1]+predtable[2,2])/nrow(testset)
    print(paste("Percent correct as binary:",perccorrect))
    
    print(paste("MSE (binary):",(1/n*sum((predbin-testset[,1])^2))))
    
    print(paste("MSE (raw):",(1/n*sum((pred-testset[,1])^2))))    
}

summarizemodel<-function(model,trainset) {
    modelsummary<-as.data.frame(summary(model)$coefficients)
    
    ##Add column for itemIds without the 'item' word
    modelsummary<-cbind("itemId"=gsub("item","",rownames(modelsummary)),modelsummary)
    
    ##Calls the static item data call to get the names and other info for items
    if(!exists("itemtable")) {
        source('./StatMouse/R/GetGames.R')
        itemtable<-itemtablecreate()
        itemtable<<-itemtable
    }
    
    modelsummary<-merge(modelsummary,itemtable,by="itemId",all.x=TRUE)
    modelsummary<-modelsummary[colnames(modelsummary)[c(1,6,2:5)]]
    
    ##Find lower and upper bounds of Estimates with 95% confidence
    n<-nrow(trainset)
    modelsummary$lowerbound<-round(modelsummary$Estimate-modelsummary[,"Std. Error"]*qt(0.975,df=n-1),9)
    modelsummary$upperbound<-round(modelsummary$Estimate+modelsummary[,"Std. Error"]*qt(0.975,df=n-1),9)
    
    ##Find counts of each item to remove any below a certain threshold, consider doing this above in widedata
    itemcounts<-data.frame("itemId"=colnames(trainset),"count"=0)
    itemcounts$itemId<-as.character(itemcounts$itemId)    
    for(i in 1:nrow(itemcounts)) {
        itemcounts$count[i]<-sum(trainset[,as.character(itemcounts$itemId[i])])
    }
    
    ##Remove the item word so we can merge in to the modelsummary
    itemcounts$itemId<-gsub("item","",itemcounts$itemId)
    modelsummary<-merge(modelsummary,itemcounts,by="itemId",all.x=TRUE)
    
    ##Temporarily removing these. We will want to include them later when we have bigger data, and more clear definitions of what
    ##the enchantments are and different bonetooth necklaces. But I think trinkets in particular need to be rated differently, and possibly
    ##regressed separately.
    modelsummary<-modelsummary[!grepl("Trinket",modelsummary$itemName),]
    modelsummary<-modelsummary[!grepl("Enchantment",modelsummary$itemName),]
    modelsummary<-modelsummary[!grepl("Bonetooth Necklace",modelsummary$itemName),]
        
    ##Keep only items that are in more than 1% of games (2% of training set), consider tinkering with this as we get bigger data
    modelsummary<-modelsummary[modelsummary$count>(n/50),] 
    
    ##Takes lowest 20 p-values, so that we get the same number of items at the end, but now this doesn't limit significance in a meaningful way
    ##Consider removing it when we have bigger data
    modelsummary<-head(modelsummary[order(modelsummary[,"Pr(>|t|)"]),],20)
    modelsummary[,"Pr(>|t|)"]<-round(modelsummary[,"Pr(>|t|)"],9)
    
    ##Create itempower, normalized with mean 5 and standard deviation 2, set max as 10 and min as 0
    ##First remove the rows for teamahead and fed player
    removerows<-c("teamahead","fedplayer")
    removerowsnum<-unlist(sapply(removerows,function(x) grep(x,as.character(modelsummary$itemId))))
    itempower<-modelsummary[-removerowsnum,"lowerbound"]
    itempowerId<-modelsummary[-removerowsnum,"itemId"]
    ipmean<-mean(itempower)
    ipsd<-sd(itempower)
    itempower<-2*((itempower-ipmean)/ipsd+2.5)
    itempower[itempower>10]<-10
    itempower[itempower<0]<-0
    
    ##Add itempower to the modelsummary
    itempower<-data.frame("itempower"=itempower,"itemId"=itempowerId)
    modelsummary<-merge(modelsummary,itempower,by="itemId",all.x=TRUE)    
    modelsummary<-modelsummary[order(-modelsummary$itempower),]
        
    return(modelsummary)
}


####DEPRECATED
analysis1<-function(modeldata) {
    ##Takes a widedata format of one champion from finalgames and returns top 10 items
    
    itemcolnums<-grep("item",colnames(modeldata))
    
    ##Set item column names to use in fitting a model
    itemcols<-paste(colnames(modeldata)[itemcolnums],collapse=" + ")   
    
    ##model is work in progress, doesn't account for gold currently
    #model<-glm(paste0("winner ~ teamPercGold + ",itemcols),data=modeldata,family=binomial) 
    model<-glm(paste0("winner ~ ",itemcols),data=modeldata,family=binomial) 
    
    modelsummary<-summary(model)
    modelsummary<-modelsummary$coefficients ##saving the coefficients as the model output
    
    modelsummary<-as.data.frame(modelsummary)
    modelsummary<-cbind("itemId"=gsub("item","",rownames(modelsummary)),modelsummary)
    
    ##Calls the static item data call to get the names and other info for items
    if(!exists("itemtable")) {
        source('./StatMouse/R/GetGames.R')
        itemtable<-itemtablecreate()
        itemtable<<-itemtable
    }
    
    modelsummary<-merge(modelsummary,itemtable,by="itemId",all.x=TRUE)
    modelsummary<-modelsummary[colnames(modelsummary)[c(1,6,2:5)]]
    modelsummary<-modelsummary[order(-modelsummary$Estimate),]
    
    ##Set this value to z if using binomial method, otherwise use t for continuous variables
    if(model$family$family=="binomial") {
        pcol<-"Pr(>|z|)"
    } else {
        pcol<-"Pr(>|t|)"
    }

    ##Filter for only reasonable outputs
    modelsummary<-modelsummary[modelsummary[,pcol]<0.5,] ##Only outputs values of a certain p-value
    modelsummary<-modelsummary[modelsummary[,"Std. Error"]<5,] ##Only outputs values of a certain standard error, maybe redundant
    
    ##Remove invalid items
    modelsummary<-modelsummary[!grepl("Trinket",modelsummary$itemName),]
    modelsummary<-modelsummary[!grepl("Enchantment",modelsummary$itemName),]
    modelsummary<-modelsummary[!grepl("Head of Kha",modelsummary$itemName),]
    modelsummary<-modelsummary[!grepl("Bonetooth Necklace",modelsummary$itemName),]
    modelsummary<-modelsummary[!grepl("Intercept",modelsummary$itemId),]
    modelsummary<-modelsummary[!grepl("teamPercGold",modelsummary$itemId),]
    
    ##Create itemPower    
    modelsummary$itemPower<-log(abs(modelsummary$Estimate/modelsummary[,pcol]))
    modelsummary[modelsummary$Estimate<0,"itemPower"]<-abs(modelsummary[modelsummary$Estimate<0,"itemPower"])*(-1)
    itempmin<-min(modelsummary[modelsummary$itemPower>-Inf,"itemPower"])
    itempmax<-max(modelsummary[modelsummary$itemPower<Inf,"itemPower"])
    modelsummary[modelsummary$itemPower==-Inf,"itemPower"]<-itempmin*2
    modelsummary[modelsummary$itemPower==Inf,"itemPower"]<-itempmax*2
    itempmin<-min(modelsummary$itemPower)
    itempmax<-max(modelsummary$itemPower)
    modelsummary$itemPower<-(modelsummary$itemPower-itempmin)/(itempmax-itempmin)*5
    
    ##Sorting modelsummary by itemPower
    modelsummary<-modelsummary[order(-modelsummary$itemPower),]
    modelsummary[,"itemPower"]<-round(modelsummary[,"itemPower"],2)  
    modelsummary[,pcol]<-round(modelsummary[,pcol],6) ##Rounding
    
    modelsummary<-modelsummary[,-c(3,4,5,6)] ##Remove extra columns, keep only items and item summary
    
    ##Keep at most 10 items
#     if(nrow(modelsummary)>10) {
#         modelsummary<-modelsummary[c(1:10),]
#     }
    
    return(modelsummary)
}