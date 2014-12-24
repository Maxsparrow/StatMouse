createmodel <- function(champlist="ALL") {
    ##Also, consider doing a k-nearest neighbor classification based on item builds
    ##Then you can do a regression analysis on each 'group' created by knn and list the items in 
    ##the best 1 or 2 groups. This seems like the best idea.
    
    ##Call randomForest library for model creation
    library(randomForest)
        
    ##If we want to analyze all champions, find the full list of champions and go through them, replace apostrophes with double apostrophes for SQL purposes
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
        
        ##Call function to summarize the fit and create itempower for each item
        modelsummary<-gamephaseitemsummary(widedata)
        
        ##Print this to see the results as we load it
        print(modelsummary)
        
        ##Add the date the analysis was run and champion name to our model data
        todaydt<-Sys.time()
        modelsummary<-cbind(todaydt,champion,modelsummary)
        colnames(modelsummary)[1:2]<-c("analysisDate","championName")
                
        ##Add this champion to the list of all champions
        allchamps<-rbind(modelsummary,allchamps)
    }
    
    ##Convert names back to one apostrophe for Cho'Gath and the like, I think they will still load into the database fine
    allchamps$championName<-gsub("''","'",allchamps$championName)
    
    return(allchamps)
}

makewidedata<-function(champion="ALL") {
    ##Select a champion to get games data for or use ALL/default for all games
    
    ##Load needed functions from other file and needed libraries
    source('./StatMouse/R/SharedAssets.R')   
    library(reshape2)
    
    ##Connect to database
    con<-reconnectdb("statmous_gamedata")
    
    ##Set the string to use in our search. If all champions are pulled use a blank string
    if(champion=="ALL") {
        champstring<-""
    } else {
        champstring<-paste0("WHERE championName='",champion,"'")
    }
    ##Get gamedata, keep matchId so we get a unique identifier for transformations
    champgames<-dbGetQuery(con,paste0("SELECT matchId,winner,matchDuration,KDA,goldEarned,teamPercGold,playerPercGold,item0,item1,item2,item3,item4,item5,item6
                                      FROM statmous_gamedata.games ",champstring," AND createDate>='",patchdate,"';"))
    champgames<-unique(champgames)
        
    ##Set item variables as character class
    itemcols<-grep("item",colnames(champgames))
    for (i in itemcols) {
        champgames[,i]<-as.character(champgames[,i])
    }    
    
    ##Remove item6 column for trinkets for the time being, they should be analyzed separately
    champgames<-champgames[,-grep("item6",colnames(champgames))]
    
    ##Experiment with these two variables and see if they give better linear regression results - i like these so far
    champgames$teamahead<-0
    champgames[champgames$teamPercGold>0.50,"teamahead"]<-1   
    champgames$fedplayer<-0
    champgames[champgames$playerPercGold>0.12,"fedplayer"]<-1 
    champgames$gameGold<-champgames$goldEarned/champgames$playerPercGold
    
    ##Set variables to keep as static vars
    idvars<-c("matchId","winner","matchDuration","KDA","goldEarned","gameGold","teamPercGold","playerPercGold","teamahead","fedplayer")
    
    ##Melt data frame
    long.champgames<-melt(champgames,id.vars=idvars)  
    
    ##Create a concatenation of the id variables with plus signs to use in dcast
    idsum<-paste(idvars,collapse=" + ")
    
    ##recast the data adding up the count of each item for each match/summoner
    widedata<-dcast(long.champgames,paste(idsum,"value",sep="~"),length,fill=0)  ##Makes each item variable a count (can be more than 1 of an item)
    #widedata<-dcast(long.champgames,paste(idsum,"value",sep="~"),function(x) 1,fill=0)   ##Makes each item variable binary based on whether it exists
    
    ##Cut out the '0' column indicating missing items
    zerocol<-grep("^[0]$",colnames(widedata))
    widedata<-widedata[,-zerocol]
    
    ##Remove matchId,teamahead, and fedplayer because we won't need them anymore
    unneededcols<-c("matchId","teamahead","fedplayer")
    for(colname in unneededcols) {
        colnum<-grep(colname,colnames(widedata))
        widedata<-widedata[,-colnum]
    }
    
    ##add 'item' before each item column
    itemcolstart<-grep("1",colnames(widedata))[1]
    for (i in itemcolstart:ncol(widedata)) {
        colnames(widedata)[i]<-paste0("item",colnames(widedata)[i])
    }
    
    ##Set winner column to a factor so model fitting sees it as classification problem
    widedata$winner<-as.factor(widedata$winner)
    
    return(widedata)
}

basicstats <- function() {    
    ##Finds basic info about all champions such as win rate, popularity, and role
    
    ##Connect to DB and pull all games since last patch
    con<-reconnectdb("statmous_gamedata")
    allgames<-dbGetQuery(con,paste0("SELECT * FROM games WHERE createDate>='",patchdate,"';"))
    
    ##Find winrate and count of games for each champion
    cwinrate<-aggregate(winner~championName,data=allgames,mean)
    cwinrate$winner<-round(cwinrate$winner,4)*100
    counts<-aggregate(matchId~championName,data=allgames,function(x) round(length(x)/length(unique(allgames$matchId)),4)*100)
    
    ##Merge the data for each champion together
    cwinrate<-merge(cwinrate,counts,by="championName")
    
    ##Need to find where the roles are in my desktop
    roles<-read.csv("champion roles.csv")
    
    ##Add roles for each champion
    cwinrate<-merge(cwinrate,roles,by="championName")
    
    ##sort the data and return it
    cwinrate<-cwinrate[order(cwinrate$role,-cwinrate$winner),]
    
    colnames(cwinrate)[2:3]<-c("winPerc","gamePerc")
    
    return(cwinrate)
}

splitdf <- function(dataframe, seed=NULL) {
    ##Splits data set into 60% training set and 40% test set. Suggested by Jeff Leek for mid range sample size
    if (!is.null(seed)) set.seed(seed)
    index <- 1:nrow(dataframe)
    trainindex <- sample(index, trunc(length(index)*.6))
    trainset <- dataframe[trainindex, ]
    testset <- dataframe[-trainindex, ]
    list(trainset=trainset,testset=testset)
}

measuremodel<-function(model,testset) {
    ##Input a fit or model from glm and a testset - use trainset while fine tuning the model, testset only for a final run
    n<-nrow(testset)
    
    ##Since winner is a factor now, change it to numeric
    testset[,1]<-as.numeric(as.character(testset[,1]))
    
    ##Find predictions as binary values
    pred<-as.numeric(as.character(predict(model,testset[,-1],type="response")))
    predbin<-pred
    predbin[predbin<0.5]<-0
    predbin[predbin>=0.5]<-1
    
    ##Find percent correct out of all observations
    predtable<-table(predbin,testset[,1])
    print(predtable)
    perccorrect<-(predtable[1,1]+predtable[2,2])/nrow(testset)
    print(paste("Percent correct as binary:",perccorrect))
    
    ##Find mean squared error, change this to a better evaluator for classification like ROC, deviance
    print(paste("MSE (binary):",(1/n*sum((predbin-testset[,1])^2))))
    print(paste("MSE (raw):",(1/n*sum((pred-testset[,1])^2))))    
}

summarizerf<-function(model,trainset) {
    library(randomForest)
    
    ##Summarizes Random Forest models. Input a random forest fit and a training set and it will output itemPower table
    modelsummary<-round(importance(model),6)
    
    ##Add column for itemIds without the 'item' word
    modelsummary<-cbind("itemId"=gsub("item","",rownames(modelsummary)),modelsummary)
    
    ##Calls the static item data call to get the names and other info for items and merges it to our table
    if(!exists("itemtable")) {
        source('./StatMouse/R/SharedAssets.R')
        itemtable<-itemtablecreate()
        itemtable<<-itemtable
    }
    modelsummary<-merge(modelsummary,itemtable,by="itemId",all.x=TRUE)
    
    ##reset winner field as numeric to take mean below
    trainset$winner<-as.numeric(as.character(trainset$winner))
    
    ##Find popularity (frequency) of each item to remove any below a certain threshold
    ##Also including win percentage for testing and comparison purposes, but remove before sharing, it is misleading
    itemcounts<-data.frame("itemId"=colnames(trainset),"popularityPerc"=0,"winPerc"=0)
    for(i in 1:nrow(itemcounts)) {
        itemcounts$popularityPerc[i]<-round(sum(trainset[,as.character(itemcounts$itemId[i])])/nrow(trainset),4)*100
        itemcounts$winPerc[i]<-round(mean(trainset[trainset[,as.character(itemcounts$itemId[i])]>0,"winner"]),4)*100
    }
    
    ##Remove the item word so we can merge in to the modelsummary
    itemcounts$itemId<-gsub("item","",itemcounts$itemId)
    modelsummary<-merge(modelsummary,itemcounts,by="itemId",all.x=TRUE)
    
    ##Keep only items that are in more than 1% of games (2% of training set), consider tinkering with this as we get bigger data
    modelsummary<-modelsummary[modelsummary$popularityPerc>2,] 
    
    ##Create itempower, normalized with mean 5 and standard deviation 2, set max as 10 and min as 0
    ##First remove the rows for teamahead and fed player
    removerows<-c("teamahead","fedplayer","teamPercGold","playerPercGold","Intercept","gameGold","goldEarned","KDA","matchDuration")
    removerowsnum<-unlist(sapply(removerows,function(x) grep(x,as.character(modelsummary$itemId))))
    itempower<-as.numeric(as.character(modelsummary[-removerowsnum,"MeanDecreaseGini"]))
    itempowerId<-as.numeric(as.character(modelsummary[-removerowsnum,"itemId"]))
    ipmean<-mean(itempower)
    ipsd<-sd(itempower)
    itempower<-2*((itempower-ipmean)/ipsd+2.5)
    itempower[itempower>10]<-10
    itempower[itempower<0]<-0
    
    ##Add itempower to the modelsummary
    itempower<-data.frame("itempower"=itempower,"itemId"=itempowerId)
    modelsummary<-merge(modelsummary,itempower,by="itemId",all.x=TRUE)    
    
    modelsummary$itempower<-round(modelsummary$itempower,2)
    modelsummary<-modelsummary[order(-modelsummary$itempower),]
    
    return(modelsummary)
}

gamephaseitemsummary<-function(trainset,limitingvar="matchDuration") {  
    ##Finds best items using a training set and randomForest algorithm broken down by early, mid, and late game
    ##Currently matchDuration is used to determine game phase, but other variables like champion level, tower, dragon, or baron kills could be used later
    library(randomForest)
    
    ##Create a subset of the training set for only games that were won in the early game and fit a randomForest
    trainearly<-trainset[trainset[,limitingvar]<=1500,]  
    fitearly<-randomForest(winner~.,data=trainearly)
    
    ##Output accuracy to show progress as we go, summarize the randomForest importance and find the best items from it
    measuremodel(fitearly,trainearly) ##Only output to show accuracy as we go
    summaryearly<-summarizerf(fitearly,trainearly)
    summaryearly$gamePhase<-"early"
    
    ##Create a subset of the training set for only games that were won in the mid game and fit a randomForest
    trainmid<-trainset[trainset[,limitingvar]>1500 & trainset[,limitingvar]<2700,]
    fitmid<-randomForest(winner~.,data=trainmid)
    
    ##Output accuracy to show progress as we go, summarize the randomForest importance and find the best items from it
    measuremodel(fitmid,trainmid) 
    summarymid<-summarizerf(fitmid,trainmid)
    summarymid$gamePhase<-"mid"
    
    ##Create a subset of the training set for only games that were won in the late game and fit a randomForest
    trainlate<-trainset[trainset[,limitingvar]>=2700,]
    fitlate<-randomForest(winner~.,data=trainlate)
    
    ##Output accuracy to show progress as we go, summarize the randomForest importance and find the best items from it
    measuremodel(fitlate,trainlate)
    summarylate<-summarizerf(fitlate,trainlate)
    summarylate$gamePhase<-"late"
    
    ##Combine early, mid, and late game summaries
    combinedsummary<-rbind(summaryearly,summarymid,summarylate)
    
    ##Loop through every unique item in our combined list, and find which gamePhase it is best in, then add that row, including its itempower, to the 
    ##final data frame for output - this is for removing duplicates
    finalsummary<-data.frame()
    curitems<-unique(combinedsummary$itemId)
    for(id in curitems) {
        cursummary<-combinedsummary[combinedsummary$itemId==id,]
        finalsummary<-rbind(finalsummary,cursummary[order(-cursummary$itempower),][1,])
    }
    #finalsummary<-combinedsummary     ##This is for use when we don't remove duplicates above


    ##Remove MeanDecreaseGini column since we don't need it and any non item rows    
    finalsummary<-subset(finalsummary,select=-c(MeanDecreaseGini))
    finalsummary<-subset(finalsummary,!is.na(finalsummary$itempower))
    
    ##Sort by gamePhase and then itempower
    finalsummary<-finalsummary[order(finalsummary$gamePhase,-finalsummary$itempower),]
    
    ##Keep only the top 10 items for each gamePhase. Could shorten further later on, but this is good for now
    finalsummary2<-rbind(head(finalsummary[finalsummary$gamePhase=="early",],10),
                         head(finalsummary[finalsummary$gamePhase=="mid",],10),
                         head(finalsummary[finalsummary$gamePhase=="late",],10))
    
    return(finalsummary2)    
}

summarizereg<-function(model,trainset) {
    ##Summarize regression models. Input a fit and a training set and it will output an itemPower table
    
    ##Set column to use for p-values, this is based on the type of function, whether it is binomial or not
    pcol<-"Pr(>|t|)"    
    
    ##Create a data frame with the model coefficients and their p values
    modelsummary<-as.data.frame(summary(model)$coefficients)
    
    ##Add column for itemIds without the 'item' word
    modelsummary<-cbind("itemId"=gsub("item","",rownames(modelsummary)),modelsummary)
    
    ##Calls the static item data call to get the names and other info for items
    if(!exists("itemtable")) {
        source('./StatMouse/R/SharedAssets.R')
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
    
    ##Enchantments can be removed if they are confusing. Need to find a way to make it more clear what they belong to. 
    ##Trinkets are now removed higher up in the makewidedata function
    #modelsummary<-modelsummary[!grepl("Enchantment",modelsummary$itemName),]
        
    ##Keep only items that are in more than 1% of games (2% of training set), consider tinkering with this as we get bigger data
    modelsummary<-modelsummary[modelsummary$count>(n/50),] 
    
    ##Takes lowest 20 p-values, so that we get the same number of items at the end, but now this doesn't limit significance in a meaningful way
    ##Consider removing it when we have bigger data
    modelsummary<-head(modelsummary[order(modelsummary[,pcol]),],20)
    modelsummary[,pcol]<-round(modelsummary[,pcol],9)
    
    ##Create itempower, normalized with mean 5 and standard deviation 2, set max as 10 and min as 0
    ##First remove the rows for teamahead and fed player
    removerows<-c("teamahead","fedplayer","Intercept","matchDuration","playerPercGold","winner")
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
        source('./StatMouse/R/SharedAssets.R')
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
