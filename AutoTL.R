setwd("~/OneDrive/AutoTL") 

library(lsa)
library(igraph)
library(e1071)
source("wikipediaHelpers.R")


C=data.frame(
  Name = c("Crypt", "Electronics", "Medicine", "Space"),
  TrainDir = c("20news-bydate-train/sci.crypt","20news-bydate-train/sci.electronics","20news-bydate-train/sci.med","20news-bydate-train/sci.space"),  
  TestDir = c("20news-bydate-test/sci.crypt","20news-bydate-test/sci.electronics","20news-bydate-test/sci.med","20news-bydate-test/sci.space")
)

# load corpus . see loadCorpus.txt for some hints
getCorpus = function(dir) { 
  print(paste0("Reading directory ",dir))
  textmatrix( dir, stemming=FALSE, language="english",
                              minWordLength=2, maxWordLength=20, minDocFreq=2,
                              maxDocFreq=FALSE, minGlobFreq=FALSE, maxGlobFreq=FALSE,
                              stopwords=NULL, vocabulary=NULL, phrases=NULL,
                              removeXML=TRUE, removeNumbers=FALSE)
}
C$TrainCorpus = lapply(as.character(C$TrainDir), getCorpus)
C$TestCorpus = lapply(as.character(C$TestDir), getCorpus)

save(C, file="C0.RData")

# pointwise mutual information
# construct term-topic matrix, including only terms that appear in both topics
countWordsInCorpus = function(corp) {
  return(apply(corp, 1, sum))
}
C$TrainTermCount = lapply(C$TrainCorpus, countWordsInCorpus)
C$TestTermCount  = lapply(C$TestCorpus, countWordsInCorpus)

save(C, file="C1.RData")

# build term-label count matrix of train set
trainTermLabels = data.frame(C$TrainTermCount[[1]])
colnames(trainTermLabels) = as.character(C$Name[1])
for (catid in 2:length( C$TrainTermCount)){
  trainTermLabels = merge(trainTermLabels, C$TrainTermCount[[catid]] , by=0, all=TRUE)
  rownames(trainTermLabels) = trainTermLabels$Row.names
  trainTermLabels$Row.names = NULL
  colnames(trainTermLabels)[catid] = as.character(C$Name[catid])
}
trainTermLabels[is.na(trainTermLabels)]=0.1

# build term-label count matrix of test set
testTermLabels = data.frame(C$TestTermCount[[1]])
colnames(testTermLabels) = as.character(C$Name[1])
for (catid in 2:length( C$TestTermCount)){
  testTermLabels = merge(testTermLabels, C$TestTermCount[[catid]] , by=0, all=TRUE)
  rownames(testTermLabels) = testTermLabels$Row.names
  testTermLabels$Row.names = NULL
  colnames(testTermLabels)[catid] = as.character(C$Name[catid])
}
testTermLabels[is.na(testTermLabels)]=0.1


# calculate pointwise mutual information for each term in each category
#p(y) = C$TotalWordsPerCategoryTrain / totalWordsAllCategoriesTrain
#p(x) = trainTermLabelsHelper$TotalCount / totalWordsAllCategoriesTrain
#p(x,y) = trainTermLabels / totalWordsAllCategoriesTrain

C$TotalWordsPerCategoryTrain = unlist(lapply(trainTermLabels, sum))
totalWordsAllCategoriesTrain = sum(C$TotalWordsPerCategoryTrain)
C$TotalWordsOtherCategoriesTrain = totalWordsAllCategoriesTrain - C$TotalWordsPerCategoryTrain
Py =  C$TotalWordsPerCategoryTrain / totalWordsAllCategoriesTrain
Px = apply(trainTermLabels , 1 , sum) / totalWordsAllCategoriesTrain
Pxy = trainTermLabels / totalWordsAllCategoriesTrain
Pmi = Pxy * log2( Pxy / (Px %o% Py))

# build query lists out of most important keywords
QUERY_SIZE = 6
queryThreashold = apply(apply(apply(Pmi , 2 , sort), 2 , tail , n=QUERY_SIZE ), 2 , head , n=1)
fetchTermsAboveThreashold = function(catname) {
  rownames(trainTermLabels)[which(Pmi[catname] >= queryThreashold[catname])]
}
queryTerms = lapply(C$Name , fetchTermsAboveThreashold)
# fetch source corpus from wikipedia
sourceCorpus = lapply(lapply(queryTerms , wikipediaSearchEach),textArray2Matrix)


# build term-label matrix for source corpus
sourceTermCount = lapply(sourceCorpus, countWordsInCorpus)
sourceTermLabels = data.frame(sourceTermCount[[1]])
colnames(sourceTermLabels) = as.character(C$Name[1])
for (catid in 2:length( sourceCorpus)){
  sourceTermLabels = merge(sourceTermLabels, sourceTermCount[[catid]] , by=0, all=TRUE)
  rownames(sourceTermLabels) = sourceTermLabels$Row.names
  sourceTermLabels$Row.names = NULL
  colnames(sourceTermLabels)[catid] = as.character(C$Name[catid])
}
sourceTermLabels[is.na(sourceTermLabels)]=0.1

C$TotalWordsPerCategorySource = unlist(lapply(sourceTermLabels, sum))
totalWordsAllCategoriesSource = sum(C$TotalWordsPerCategorySource)
C$TotalWordsOtherCategoriesSource = totalWordsAllCategoriesSource - C$TotalWordsPerCategorySource

# Word Frequency weight
sourceTermLabelsCf = sourceTermLabels / C$TotalWordsPerCategorySource
sourceTermLabelsOf = sourceTermLabels / C$TotalWordsOtherCategoriesSource
sourceTermLabelsFW = log2(sourceTermLabelsCf)/log2(sourceTermLabelsOf)

# Entropy weight
sourceTermLabelsGf = apply(sourceTermLabels , 1 , sum) / totalWordsAllCategoriesSource
sourceTermLabelsCW = log(length(C$Name)) + 
  (
    (sourceTermLabelsCf / sourceTermLabelsGf)
    *
      log2(sourceTermLabelsCf / sourceTermLabelsGf)
  )

# Feature weight
sourceTermLabelsW = sourceTermLabelsFW * sourceTermLabelsCW

# top 10 weight terms
TRANSFER_SIZE = 10
transferThreashold = apply(apply(apply(sourceTermLabelsW , 2 , sort), 2 , tail , n=TRANSFER_SIZE ), 2 , head , n=1)
fetchTermsBelowThreashold = function(catname) {
  rownames(sourceTermLabels)[which(sourceTermLabelsW[catname] >= transferThreashold[catname])]
}
transferTerms = lapply(C$Name , fetchTermsBelowThreashold)


# costruct feature set out of top weight terms from both labels + query terms
features = c (
  unlist(queryTerms),
  unlist(transferTerms)
  )

# create classification dataset by merging test and train records
allrecords = data.frame()
for (catid in 1:length(C$Name)) {
  tomerge = C$TestCorpus[[catid]][which(rownames(C$TestCorpus[[catid]]) %in% features),]
  colnames(tomerge)=paste0(C$Name[catid],".TEST.",colnames(tomerge))
  allrecords = merge( 
    allrecords,
    tomerge ,
    by=0, all=TRUE
    )
  rownames(allrecords) = allrecords$Row.names
  allrecords$Row.names = NULL
  
  tomerge = C$TrainCorpus[[catid]][which(rownames(C$TrainCorpus[[catid]]) %in% features),]
  colnames(tomerge)=paste0(C$Name[catid],".TRAIN.",colnames(tomerge))
  allrecords = merge( 
    allrecords,
    tomerge ,
    by=0, all=TRUE
  )
  rownames(allrecords) = allrecords$Row.names
  allrecords$Row.names = NULL
}
allrecords[is.na(allrecords)]=0

WbeforeCutoff=as.matrix(dist(t(allrecords)))


catLabel = unlist(lapply(colnames(allrecords), function(x) { strsplit(x,"\\.")[[1]][1] } ))
trainIdx =  grep("\\.TRAIN\\.", colnames(allrecords))
isTrain = 1:length(catLabel) %in% trainIdx

beta=1000 # larger than 1, control size of weigths
graphLabeledSameCat= as.matrix(  sqrt(1- ( exp(-(dist(t(allrecords))^2)) / beta )   )  )
graphLabeledDiffCat= as.matrix(  sqrt( ( exp( ( dist(t(allrecords))^2) ) / beta )   )  )
WbeforeCutoff[isTrain,isTrain] = graphLabeledDiffCat[isTrain,isTrain]
for (catname in C$Name) {
  WbeforeCutoff[isTrain & (catLabel==catname) , isTrain & (catLabel==catname)] = 
    graphLabeledSameCat[isTrain & (catLabel==catname) , isTrain & (catLabel==catname)]
}

isSymmetric(WbeforeCutoff)
save(WbeforeCutoff , file="WbeforeCutoff.RData")

# inspect graph:
#number of isolated nodes: sum(apply(W,2,sum)==0)
step = 500
dir=0
min_step=10
cutoff = 1000
resulting_clusters=2
print("Finding best cutoff for one connected graph")
while (step>1 | resulting_clusters>1) {
  W=ifelse(WbeforeCutoff>cutoff,0,1)
  g = graph_from_adjacency_matrix(W, mode = c("undirected"), diag=FALSE)
  resulting_clusters = clusters(g)$no
  print(paste0("Cutoff: ",cutoff," Step: ",step," Clusters: ", resulting_clusters))
  if (resulting_clusters > 1) {
    cutoff = cutoff + step
    if(dir==-1) { step = step/2 }  
    dir=1
  } else {
    if (step==cutoff) { step = step/2 }
    cutoff = cutoff - step
    if(dir==1) { step = step/2 }  
    dir=-1
  }
}

# validate: count number of connections between test documents in the same and different categories


D=diag(apply(W,2,sum))
L = D - W
outdata = eigen(L)

save(outdata , file="reducedFeatures.RData")
save(W , file="W.RData")


numberOfReducedFeatured=100
trainLabels = as.factor(catLabel[isTrain])
testLabels = as.factor(catLabel[!isTrain])

# SVM
linear.svm = svm(outdata$vectors[isTrain, 1:numberOfReducedFeatured ], y = trainLabels, kernel="linear")
poly.svm =  svm(outdata$vectors[isTrain, 1:numberOfReducedFeatured], y = trainLabels, kernel="polynomial")
radial.svm =  svm(outdata$vectors[isTrain, 1:numberOfReducedFeatured], y = trainLabels, kernel="radial")
sigmoid.svm =  svm(outdata$vectors[isTrain, 1:numberOfReducedFeatured], y = trainLabels, kernel="sigmoid")

pred = predict(linear.svm,outdata$vectors[!isTrain, 1:numberOfReducedFeatured ])
mean(pred==testLabels)
table(pred,testLabels)
pred = predict(poly.svm,outdata$vectors[!isTrain, 1:numberOfReducedFeatured ])
mean(pred==testLabels)
table(pred,testLabels)
pred = predict(radial.svm,outdata$vectors[!isTrain, 1:numberOfReducedFeatured ])
mean(pred==testLabels)
table(pred,testLabels)
pred = predict(sigmoid.svm,outdata$vectors[!isTrain, 1:numberOfReducedFeatured ])
mean(pred==testLabels)
table(pred,testLabels)



library(randomForest)
rf=randomForest(outdata$vectors[isTrain, 1:numberOfReducedFeatured ], y = trainLabels)
pred = predict(rf,outdata$vectors[!isTrain, 1:numberOfReducedFeatured ])
mean(pred==testLabels)
table(pred,testLabels)

