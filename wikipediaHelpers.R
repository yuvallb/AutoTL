library(jsonlite)
library(lsa)
wiki2text = function(txt) {
  txt = gsub("\n"," ",txt, fixed=TRUE)
  txt = gsub("<br>"," ",txt, fixed=TRUE)
  txt = gsub("''","",txt, fixed=TRUE)
  txt=gsub("[[","",txt, fixed=TRUE)
  txt=gsub("]]","",txt, fixed=TRUE)
  txt=gsub("{{","",txt, fixed=TRUE)
  txt=gsub("}}","",txt, fixed=TRUE)
  txt=gsub("|","",txt, fixed=TRUE)
  txt=gsub("===","",txt, fixed=TRUE)
  txt=gsub("==","",txt, fixed=TRUE)
  return(txt)
}
wikipediaArticle = function(title) {
  url=paste0("https://en.wikipedia.org/w/api.php?action=query&prop=revisions&rvprop=content&format=json&titles=",URLencode(title))
  html = fromJSON(url, flatten = TRUE)
  return(wiki2text(html$query$pages[[1]]$revisions$`*`))
}

# search a keyword in wikipedia and return a list of titles
wikipediaGetTitles = function(keyword) {
  url=paste0("https://en.wikipedia.org/w/api.php?action=query&list=search&srwhat=text&format=json&srsearch=",URLencode(keyword))
  results = fromJSON(url)
  if (results$query$searchinfo$totalhits>0) {
    titles = results$query$search[,"title"]
    return(titles)
  } 
  return(NULL)
}
# search a list of keywords - return full text of articles
wikipediaSearchAll = function(keywords) {
  while (length(keywords)>1) {
    results = wikipediaGetTitles(paste0(keywords, collapse = ' '))
    if (length(results)>0) {
      titles = results$query$search[,"title"]
      print(paste0("Retrieving wikipedia titles: ",paste0(titles, collapse=", ")))
      return(lapply(titles,  wikipediaArticle) )
    } else {
      keywords = keywords[-length(keywords)]
    }
  }
}
# search one keyword - return full text of articles
wikipediaSearch1 = function(keyword) {
  results = wikipediaGetTitles(keyword)
  if (length(results)>0) {
      print(paste0("Retrieving wikipedia titles: ",paste0(results, collapse=", ")))
      return(unlist(lapply(results,  wikipediaArticle) ))
  } 
  return(NULL)
}
# search a list of keywords - return full text of articles for each keyword
wikipediaSearchEach = function(keywords) {
  titles = unique(unlist(lapply(keywords, wikipediaGetTitles)))
  if (length(titles)>0) {
    print(paste0("Retrieving wikipedia titles: ",paste0(titles, collapse=", ")))
    return(unlist(lapply(titles,  wikipediaArticle) ))
  } 
  return(NULL)
}
textArray2Matrix = function(txtArray) {
  td = tempfile()
  dir.create(td)
  docid=1
  for (txt in txtArray) {
    write(txt, file=paste(td, docid, sep="/") )
    docid=docid+1
  }
  return(textmatrix(td, stemming=FALSE, language="english",
                    minWordLength=2, maxWordLength=20, minDocFreq=1,
                    maxDocFreq=FALSE, minGlobFreq=3, maxGlobFreq=FALSE,
                    stopwords=NULL, vocabulary=NULL, phrases=NULL,
                    removeXML=TRUE, removeNumbers=FALSE))
}


