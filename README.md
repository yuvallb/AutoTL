## AutoTL - Automatic transfer learning for short text mining

An R implementation of the AutoTL algorithm as presented in:
Yang, L., & Zhang, J. (2017). Automatic transfer learning for short text mining. EURASIP Journal on Wireless Communications and Networking, 2017(1), 42.

	
### Algorithm overview:

The AutoTL algorithms aims at classifying short text documents where a subset of the documents is already labeled. AutoTL does that by searching the web for similar documents, and adding keywords from the online long documents to the feature set that is used to classify the target short text documents. The steps are:
1. Input: a corpus of short text documents that consists of labeled and unlabeled documents. The distribution of the unlabeled documents is unknown. This corpus will serve as the “Target” of the transfer learning. Parameters: number of documents and their categories.
2. Keyword extraction: keywords are extracted from the labeled target documents. The keywords with the largest mutual information to the labels are selected. Parameters: number of keywords to extract or mutual information threshold.
3. Online search: performing a web search for the selected keywords of each label. The documents found are used as the “Source” of the transfer learning. Parameters: online source of documents, number of documents to extract.
4. Feature weight calculation: additional keywords are extracted from the source documents. Each word is given a weight that is a multiplication of a frequency weight and an entropy weight, where frequency weight reflects the relative frequency of the word relative to other categories, and the entropy weight represents an estimation to the entropy of the word relative to the categories. Parameters: number of keyword to extract from the source corpus.
5. New feature space construction: An adjacency matrix is calculated for all documents in the “target” corpus – labeled and unlabeled. The distance between two documents is the Euclidean distance between the vector of features. This distance is corrected for labeled documents to be higher when they belong to the same class. The resulting adjacency matrix is used to calculate new features using laplacian eigenmaps. Parameters: β regulator to adjust weights of labeled documents, ε cutoff to decide if an edge will be included in the graph.
6. Classification: The top features from the laplacian eigenmaps are used to classify the unlabeled documents, using the labeled documents as the training set. Parameters: number of features, classification algorithm.

 
### Implementation specification

The following stages refer to the algorithm stages as detailed above.
1. Input: documents were read using the textmatrix function in the lsa package. Word length was set to 2-20 characters. Minimum word frequency in dataset 3, stopwords were removed according to the stopwords_en dictionary from the lsa package. More details regarding the input will be given in the experiment design section below.
2. Keyword extraction: mutual information of each word was calculated according to the method specified in the article. In each topic 6 top keywords were selected.
3. Online search: two options were examined: Wikipedia API search and Bing Web Search API. Wikipedia has the advantage of returning well formatted text, that required only a well-defined fixed set of processing, however it was returning a lot of irrelevant results. Bing search always returned relevant results, however the results were web pages and pdf files “in the wild”, it was hard to figure out a programmatic and consistent way to parse the html content into text. In light of that difficulty, Wikipedia API search was chosen. The search was implemented using the jsonlight package.
4. Feature weight calculation: a weight was assigned to each keyword. The weight calculation was done as described in the article. Top 50 keywords were selected in each category.
5. New feature space construction: distance between each document was calculated according to cosine distance using the proxy package. The Euclidean distance was not used since further adjustments specified in the article assume the distance in in the 0-1 range, which is not valid for Euclidean distance. The β parameter had a major influence on the results, and was selected to be 10 after much trial and error. The ε cutoff parameter was selected analytically as the minimal cutoff to create a connected graph. Graph connectivity calculation was done using the igraph package.
6. Classification: top 150 features from the laplacian eigenmaps were selected for classification. The classification was done using linear SVM. These were decided by trial and error. 

### Experiment design

Experiment was done on the 20 newsgroups corpus, the same as in the original article. The article displayed classification results for each main category in the dataset, within its sub categories. The article did not specify what sub categories were selected.
The “bydate” version of the 20-newsgroup dataset was used, which contains 18,846 documents sorted by date, with duplicates and some headers removed, divided into test and train folders by date.

The experiment was conducted on the following categories and stages (see summary in table 1 below):
1. sci.crypt vs. sci.electronics vs. sci.space
2. rec.autos vs. rec.sport.baseball vs. rec.sport.hockey
3. talk.politics.guns vs. talk.politics.mideast vs. talk.religion.misc
The experiment had two stages:
1. Balanced – using the original train / test division from the 20-newsgroup dataset.
2. Unbalance – using a very small train set, and a test set with modified distribution.
 

|                   |     |Sci: Crypt|Sci: Electronics|Sci:Space|Rec: Autos|Rec: Baseball|Rec: Hockey|Talk: Guns|Talk: Mideast|Talk: religion|
|-------------------|-----|----------|----------------|---------|----------|-------------|-----------|----------|-------------|--------------|
|Stage 1: Balanced  |Train|594       |591             |591      |594       |596          |600        |546       |564          |377           |
|                   |Test |396       |393             |394      |396       |397          |399        |364       |376          |251           |
|Stage 2: Unbalanced|Train|21        |3               |17       |49        |23           |50         |7         |39           |31            |
|                   |Test |396       |193             |394      |396       |397          |52         |364       |376          |25            |

Table 1: Summary of experimental stages and dataset distribution


The data was processed for UTF-8 validation, since the textmatrix function in the lsa package will fail if it encounters malformed characters.
An additional classification stage was done after extracting the additional keywords from the online source corpus and before running the laplacian eigenmaps. 
The original article claims generally that the algorithm is suitable for classifying data with a different distribution than the train set – but this claim is not asserted or evaluated in the article.
The original article does not specify exact classification results, just a bar plot that shows classification accuracy around 90%.





### Testing and Evaluation

Table 2 below shows the classification results. 
In each stage, for each of the 3 categories, two classifications were done: 
1. The first classification was after extracting the additional keywords from the online source. That classification was done on the original feature space – the features being the count of occurrences of each of the keywords extracted from the train set and from the online source set. A random forest classifier was used.
2. The second classification was done on the laplacian eigenmaps results – as specified in the original article. The classification was done on the top 150 vectors, and using a linear SVM classifier, as suggested by the article.

 

|                   |                                                      |Sci|Rec|Talk|
|-------------------|------------------------------------------------------|---|---|----|
|Stage 1: Balanced  |Classification Accuracy on original feature space (RF)|86%|83%|76% |
|                   |Classification Accuracy on new feature space (SVM)    |68%|74%|64% |
|Stage 2: Unbalanced|Classification Accuracy on original feature space (RF)|42%|69%|29% |
|                   |Classification Accuracy on new feature space (SVM)    |63%|63%|55% |

Table 2: classification results according to experiment stage and dataset


An interesting observation is that the laplacian eigenmaps lowered the classification accuracy most of the times, instead of removing noise and increasing the accuracy. This happened primarily in stage 1 of the experiment where the train and test sets were balanced and the distribution of the target unlabeled documents was similar to the distribution of the labeled documents. Laplacian eigenmaps can help compensate for these problems (Belkin 2003), where in this stage 1 they did not exist, which just added complexity, without having an advantage. Stage 2 of the experiment was aimed at evaluating this claim, and shows the laplacian eigenmaps does help improve the accuracy in 2 out of 3 categories.

The discrepancy from the original 90% to the results displayed above can be due to the selection of any of the parameters that were mentioned in the algorithm overview section. The most probable of which is the selection of train and test documents. Comparing only two subcategories instead of 3 or 4 can lead to high accuracy results. 

 
Another parameter that had very high influence on the quality of the results was the source of the online documents. The selected source in this experiment was Wikipedia, using its search API. It seems that the Wikipedia search is not very sophisticated, and many times leads to irrelevant results. For example, in the sci.crypt topic, the selected keywords were: “chip clipper encryption government key keys”, which are all relevant to the topic. In the Wikipedia search the implementation retrieved 10 documents for each of the 6 keywords, removed articles with “disambiguation” in the title, and returned the top 3 resulting articles for keyword extraction. This process sometimes resulted in non-relevant documents, as seen in an example detailed in table 3 below.

|Keyword                 |Wikipedia articles found                                     |Of which: Relevant                 |
|------------------------|-------------------------------------------------------------|-----------------------------------|
|chip                    |Chip, Chromatin immunoprecipitation, System on a chip        |Only System on a chip              |
|clipper                 |Clipper, Clipper (programming language), Clipper architecture|Only Clipper architecture          |
|encryption              |Encryption, Disk encryption, On-the-fly encryption           |All 3                              |
|government              |Government, Forms of government, E-government                |All 3                              |
|key                     |Key, KeY, Public-key cryptography                            |Only Public-key cryptography       |
|keys                    |Key, KEYS, Arrow keys                                        |None                               |
|__Total: 100% relevant__|                                                             |__Total: 9/18 – only 50% relevant__|

Table 3: Example of retrieval of source documents for the sci.encryption category from Wikipedia

 
 
### Installation and Running Instructions

The computer should be connected to the internet, since it retrieves pages from Wikipedia during run time.

The run folder should contain the following files:

runAutoTL.R		Entry point. Runs the algorithm on the files.

runAutoTL.Rout		Output file

AutoTL.R		Main algorithm file.

wikipediaHelpers.R	Helper file to fetch and format data from Wikipedia

loadCorpus.txt		Some comments regarding preprocessing text files 

20news-bydate		Document corpus in balanced/unbalanced and train/test

Running the program on the full supplied corpus should take ~30 minutes.
 


### References

Yang, L., & Zhang, J. (2017). Automatic transfer learning for short text mining. EURASIP Journal on Wireless Communications and Networking, 2017(1), 42. [http://doi.org/10.1186/s13638-017-0815-5](http://doi.org/10.1186/s13638-017-0815-5)

20 Newsgroups, [http://qwone.com/~jason/20Newsgroups/20news-bydate.tar.gz](http://qwone.com/~jason/20Newsgroups/20news-bydate.tar.gz)
Belkin M., & Niyogi P. (2003). Laplacian Eigenmaps for Dimensionality Reduction and Data Representation. Neural Computation, 2003, vol. 6, pp. 1373-1396


