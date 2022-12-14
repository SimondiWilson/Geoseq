setwd("G:/data/GEO")
getwd()

# Dependent --------------------------------------------------------------------

#packinfo <- installed.packages(fields = c("Package", "Version"));
#packinfo[,c("Package", "Version")];
library("FactoMineR");
library("factoextra");
library("ggplot2");
library("GSEABase");
library("GSVA");
library("clusterProfiler");
library("genefu");
library("GEOquery");
library("ggpubr");
library("hgu133plus2.db");
library("limma");
library("org.Hs.eg.db");
library("pheatmap");
library("BiocGenerics");
library("parallel");
library("stringr");
library("ggnewscale")
sprintf("library SUCCEED %s",date());

# GEOData Processing -----------------------------------------------------------
rm(list = ls())  # 魔幻操作，一键清空~
options(stringsAsFactors = F)
#在调用as.data.frame的时，将stringsAsFactors设置为FALSE可以避免character类型自动转化为factor类型
# 注意查看下载文件的大小，检查数据 
#~ Data downlaoding -----------------------------------------------------------

f='GSE10006_eSet.Rdata'
library(GEOquery)
#Setting options('download.file.method.GEOquery'='auto')
#Setting options('GEOquery.inmemory.gpl'=FALSE)
#下载基因表达文件保存到本地，其中注释文件和平台文件都设为F，只下载表达矩阵
if(!file.exists(f)){
  gset <- getGEO('GSE10006', destdir=".",
                 AnnotGPL = F,     # 注释文件
                 getGPL = F)       # 平台文件
  save(gset,file=f)   # 保存到本地
} ;

#~ Data cheak ------------------------------------------------------------------
load('GSE10006_eSet.Rdata')  ## 载入数据
class(gset)  #查看数据类型,返回表示list文件
length(gset)  #返回值为1 只有一个GPL平台
class(gset[[1]])#返回值：ExpressionSet
#返回值：ExpressionSet arr(,"package") Biobase
#gset返回了下载数据的相关信息，包括数据库的入口，平台,特征数，样本数，样本名称等等
gset
# assayData:  33297 features, 6 samples
# 因为这个GEO数据集只有一个GPL平台，所以下载到的是一个含有一个元素的list
#gset[[1]]是数据中的基因表达部分
a=gset[[1]] #a现在是一个对象#exprs()用来得到对象中的表达函数
dat=exprs(a) #a现在是一个对象，使用exprs这个函数将元素转化为matrix
dim(dat)#看一下dat这个矩阵的维度 # ??expressionset可以查看相关部分的性质及介绍
dat[1:4,1:6] #查看dat这个矩阵的1至4行和1至4列，逗号前为行，逗号后为列

ex <- dat
qx <- as.numeric(quantile(ex, c(0.,0.25,0.5,0.75,0.99,1.0), na.rm=T))
LogC <- (qx[5] > 100) ||
  (qx[6]-qx[1] > 50 && qx[2] > 0) ||
  (qx[2]> 0 && qx[2] < 1 && qx[4] > 1 && qx[4] < 2)
if (LogC) {ex[which(ex <= 0)] <- NaN
datexp <- log2(ex)
print("log2 transform done,save in datexp")} else {print("log2 transformed")}
dim(datexp)#看一下dat这个矩阵的维度 # ??expressionset可以查看相关部分的性质及介绍
datexp[1:4,1:6]

#质控表达矩阵是否符合下游分析。
samples=sampleNames(a) # sample name就是看有多少GSM样本
pdata=pData(a) 
# pData是看样本怎么分组。pdata此时是个data.frame
group_list=as.character(pdata[,2])

#boxplot:画箱线图
png("qc.png",width=900,height=500,units="px")
boxplot(datexp,las=2,col = "#35739b",outline = FALSE)
dev.off()

#~Matrix Comments --------------------------------------------------------------
#通过查看说明书知道取对象a里的临床信息用pData(组织，平台，转录组相关情况)
pd=pData(a) 
## GSM252855:GSM252867为contral组，GSM252828:GSM252841为COPD组。

library(stringr)
#str_split(string, pattern, n = Inf, simplify = FALSE)
#string：指定需要处理的字符串向量
#pattern：分隔符，可以是复杂的正则表达式
#n：指定切割的份数，默认所有符合条件的字符串都会被拆分开来
#simplify：是否返回字符串矩阵，默认以列表的形式返回
group_list=str_split(pd$title,',',simplify = T)[,2]
#table函数，返回各个元素及其出现的频次
table(group_list)

datexp[1:4,1:6] 
# 注释平台GPL6244
if(T){
  library(GEOquery)
  #下载注释平台文件GPL6244
  #Download GPL file, put it in the current directory, and load it:
  gpl <- getGEO('GPL570', destdir=".")
  #colnames：查看数据的列名，此处可以看到gpl有哪些元素
  #Table函数：
  colnames(Table(gpl))  
  #看前六个值
  head(Table(gpl)[,c(1,12)]) ## you need to check this , which column do you need
  probe2gene=Table(gpl)[,c(1,12)]
  head(probe2gene)
  library(stringr)  
  save(probe2gene,file='probe2gene.Rdata')  }
# load(file='probe2gene.Rdata')
# ids=probe2gene 

#载入平台对应的注释包，注释包应去相关网站查询
library(hgu133plus2.db)
ls('package:hgu133plus2.db')
#toTable这个函数：通过看hgu133plus2.db这个包的说明书知道提取probe_id（探针名）和symbol（基因名）的对应关系的表达矩阵的函数为toTable
ids=toTable(hgu133plus2SYMBOL) 
head(ids) #head为查看前六行
#更改ids文件中的列名
colnames(ids)=c('probe_id','symbol')  
#去除没有对应基因的探针
ids=ids[ids$symbol != '',]
length(unique(ids$symbol))
tail(sort(table(ids$symbol)))
# 查看重复基因 tail获取尾部的信息
png("qc_gene.png",width=500,height=500,units="px")
plot(table(sort(table(ids$symbol))))
dev.off()
#检查是否所有探针都有对应关系
#除去dat数据行名不存在探针里的数据
ids=ids[ids$probe_id %in% rownames(datexp),]
table(rownames(datexp) %in% ids$probe_id)
# %in% 返回的是true/false,所以直接用table就可显示。
# 测序集合datexp里有多少symble是在这个包里能找到的，也可以将探针的原始信息下载下来，用更全的包去注释
dim(datexp)
exprset=datexp[rownames(datexp) %in% ids$probe_id,]
length(exprset)
class(exprset)
dim(exprset)
exprset[1:4,1:6] 
# 将ids里面和exprset里面重复的行给挑出来
# match表示是否一致，并且这里是要这个行的内容
ids=ids[match(rownames(exprset),ids$probe_id),]
head(ids)
exprset[1:5,1:5]
# 因为注释矩阵的探针数量少，所以此时应该注释矩阵是个子集，取两者的交集。
table(ids$probe_id %in% rownames(exprset))
table(ids$probe_id==rownames(exprset))
# 可见所有的探针id都在我们的矩阵里能找到相应的id,并且位置完全相等（==）
# 对以上内容进行合并，merge或者cbind都可以，因为此时是一致的顺序。
new_exprset = exprset
#rownames(new_exprset)=ids$symbol
# 注意细致检查排列顺序或者有重复的矩阵id/基因
#ids新建median这一列，列名为median，同时对new_exprset这个矩阵按行操作，取每一行的中位数，将结果给到median这一列的每一行
#1表示对行进行处理，2表示对列进行处理，median所用函数
ids$median=apply(new_exprset,1,median) 
#对ids$symbol按照ids$median中位数从大到小排列的顺序排序，将对应的行赋值为一个新的ids
ids=ids[order(ids$symbol,ids$median,decreasing = T),]
#将symbol这一列取取出重复项，'!'为否，即取出不重复的项，去除重复的gene ，保留每个基因最大表达量结果
ids=ids[!duplicated(ids$symbol),]
#新的ids取出probe_id这一列，将new_exprset按照取出的这一列中的每一行组成一个新的new_exprset
new_exprset=new_exprset[ids$probe_id,] 
#把ids的symbol这一列中的每一行给new_exprset作为new_exprset的行名
rownames(new_exprset)=ids$symbol
new_exprset[1:4,1:6]  #保留每个基因ID第一次出现的信息
png("qc_gene_new.png",width=500,height=500,units="px")
plot(table(sort(table(ids$symbol))))
dev.off()
save(new_exprset,group_list,file = 'exprset-output.Rdata')
ACTB <- new_exprset['ACTB',]
png("ACTB.png",width=500,height=500,units="px")
boxplot(ACTB,las=2,col = "#35739b")
dev.off()
GAPDH <- new_exprset['GAPDH',]
png("GAPDH.png",width=500,height=500,units="px")
boxplot(GAPDH,las=2,col = "#de3122")
dev.off()





library(reshape2)
exprset_L<-melt(new_exprset) #转换为长数据
colnames(exprset_L) <- c('probe','sample','value')

library("dplyr")
library("tidyr")
## GSM252855:GSM252867为contral组，GSM252828:GSM252841为COPD组。
Control_exp = as.data.frame(new_exprset) %>% select(GSM252855:GSM252867)
Control_expL<-melt(as.matrix(Control_exp) ) #转换为长数据
colnames(Control_expL) <- c('probe','sample','value')
Control_expL$group = rep("Control")
COPD_exp = as.data.frame(new_exprset) %>% select(GSM252828:GSM252841)
COPD_expL<-melt(as.matrix(COPD_exp) ) #转换为长数据
colnames(COPD_expL) <- c('probe','sample','value')
COPD_expL$group = rep("COPD")
experset_groupL = rbind(Control_expL,COPD_expL)
experset_group = cbind(Control_exp,COPD_exp)  
experset_group = data.matrix(experset_group)
#exprset_L$group=rep(group_list,each=nrow(new_exprset))

sprintf("Exprset CLEAN SUCCEED %s",date());

#rm(list = ls())  ## 魔幻操作，一键清空~
#options(stringsAsFactors = F)
#load(file = 'exprset-output.Rdata')
#table(group_list)

# 每次都要检测数据
experset_group[1:4,1:6]
## 下面是画PCA的必须操作，需要看说明书。
#t表示转置
experset_group=t(experset_group)#画PCA图时要求是行名时样本名，列名时探针名，因此此时需要转换
experset_group=as.data.frame(experset_group)#将matrix转换为data.frame
#cbind横向追加，即将分组信息追加到最后一列
group_list= rep(c("Control","COPD"),c(13,14) ) 
group_list
experset_group=cbind(experset_group,group_list) 

library("FactoMineR")#画主成分分析图需要加载这两个包
library("factoextra") 
# before PCA analysis
experset_group <- select(experset_group,-group_list) # The variable group_list is removed
dat.pca <- PCA(experset_group[,-ncol(experset_group)], graph = FALSE)
experset_group=cbind(experset_group,group_list) #add group_list
experset_group$group_list<-as.vector(experset_group$group_list)
fviz_pca_ind(dat.pca,
             geom.ind = "point", # show points only (nbut not "text")
             col.ind = experset_group$group_list, # color by groups
             palette = c("#35739b", "#de3122"),
             addEllipses = TRUE, # Concentration ellipses
             legend.title = "Groups" 
             ) +
              coord_fixed(1) +
              theme_bw()

ggsave('all_samples_PCA.png')
#箱线
p1<-ggplot(data.frame(experset_groupL),
           aes(x = sample, y = value,fill = factor(group, levels = c("Control","COPD") ) ) )+
  stat_boxplot(geom = "errorbar",width=0.2,aes(x=sample,y=value,group=sample))+
  geom_boxplot(outlier.color = "#bdbec0",
  ) + 
  scale_fill_manual(values = c("Control"="#35739b","COPD"="#de3122"), 
                    name = "Group",
                    labels = c("Control" = "Control", "COPD" = "COPD")) +
  labs(x="",y = "Normalized signal intensity",title = "GSE10006")+
  scale_y_reverse()+
  theme_bw()+                                       #白色背景
  coord_fixed(ratio=1/2) +
  theme(axis.title.x = element_blank(),
        plot.title = element_text(hjust= 0.5),
        axis.text.x = element_text(angle = 30,vjust = 0.85,hjust = 0.75))
ggsave('all_samples_bosplot.png')

sprintf("QCPLOT SUCCEED %s",date());

#rm(list = ls()) 
#load(file = 'exprset-output.Rdata') 
#此步为一个小插曲，即计算一下从第一行开是计算每一行的sd值
experset_group[1:4,1:6]
experset_group <- select(experset_group,-group_list)
experset_group=t(experset_group)#列名时样本名，行名时探针名
#apply按行（'1'是按行取，'2'是按列取）取每一行的方差，从小到大排序，取最大的1000个
#tail函数：查看数据中的最后几行元素 #names对向量命名
#对那些提取出来的1000个基因所在的每一行取出，组合起来为一个新的表达矩阵
cg=names(tail(sort(apply(experset_group,1,sd)),1000))
library(pheatmap)
#dat([cg,]).as.numeric([cg,])
pheatmap(experset_group[cg,],show_colnames =F,show_rownames = F,
         filename = 'heatmap_top1000.png' ,
         color = colorRampPalette(c("#35739b", "white", "#de3122"))(50) ) 
# 'scale'可以对log-ratio数值进行归一化
n=t(scale(t(experset_group[cg,])))
n[n>2]=2 
n[n< -2]= -2
n[1:4,1:4]
pheatmap(n,show_colnames =F,show_rownames = F)
class(group_list)
ac=data.frame(group=group_list)
#把ac的行名给到n的列名，即对每一个探针标记上分组信息
rownames(ac)=colnames(experset_group) 

pheatmap(n,show_colnames =T,show_rownames = F,
         clustering_method = "average",
         annotation_col=ac,filename = 'heatmap_top1000_sd.png', 
         color = colorRampPalette(c("#35739b", "white", "#de3122"))(50) ,
         cluster_cols = FALSE)
# cluster_row = FALSE参数设定不对行进行聚类
# legend_breaks参数设定图例显示范围，legend_labels参数添加图例标签

#DEGs
#rm(list = ls())
#options(stringsAsFactors = F)
#load(file = 'step1-output.Rdata')
# 每次都要检测数据
experset_group[1:4,1:6] 
#table函数，查看group_list中的分组个数
table(group_list) 
#通过为每个数据集绘制箱形图，比较数据集中的数据分布
#按照group_list分组画箱线图
#boxplot(experset_group[1,]~group_list)
# bp=function(g){         #定义一个函数g，函数为{}里的内容
#   #加载绘图包
#   library(ggpubr)
#   #产生一个数据框，参数是数据框后边的内容
#   df=data.frame(gene=g,stage=group_list)
#   p <- ggboxplot(df, x = "stage", y = "gene",
#                  #颜色与背景的设置
#                  color = "stage", palette = "jco",
#                  add = "jitter")
#   #  Add p-value
#   p + stat_compare_means()
# }
# 
# bp(experset_group[1,]) ## 调用上面定义好的函数，避免同样的绘图代码重复多次敲。
# p
# bp(dat[2,])
# dim(dat)

library(limma)
#factor因子：把数据以向量的形式存储
#group_list:生物数据的分组信息
design=model.matrix(~factor( group_list ))
#limma包中的线性模型拟合，构建线性模型进行差异分析
#fit=lmFit(experset_group,design)
#用经验贝叶斯进行残差分析获得合适的t统计量
#fit=eBayes(fit)
## 上面是limma包用法的一种方式 
options(digits = 4) #设置全局的数字有效位数为4
#topTable(fit,coef=2,adjust='BH') 
## 但是上面的用法做不到随心所欲的指定任意两组进行比较

design <- model.matrix(~0+factor(group_list))
#levels:用于显示factor变量中类型不同的因子
colnames(design)=levels(factor(group_list))
head(design)
#exprSet=dat
#将列名换成行名
rownames(design)=colnames(experset_group)
design
contrast.matrix<-makeContrasts("Control-COPD",
                               levels = design)
contrast.matrix ##这个矩阵声明，我们要把 Tumor 组跟 Normal 进行差异分析比较

deg = function(exprSet,design,contrast.matrix){
  ##step1寻找差异矩阵
  fit <- lmFit(exprSet,design)
  ##step2线性拟合
  fit2 <- contrasts.fit(fit, contrast.matrix) 
  fit2 <- eBayes(fit2)  ## default no trend !!!
  ##eBayes() with trend=TRUE
  ##step3 topTable函数用于进行基因筛选
  tempOutput = topTable(fit2, coef=1, n=Inf)
  #na.omit删除含有缺失数据的行
  nrDEG = na.omit(tempOutput) 
  #write.csv(nrDEG,"limma_notrend.results.csv",quote = F)
  head(nrDEG)
  return(nrDEG)
}
deg = deg(experset_group,design,contrast.matrix)
head(deg)
save(deg,file = 'deg.Rdata')

## for volcano 

if(T){
  nrDEG=deg
  head(nrDEG)
  #attach()可将数据框添加到R的搜索路径中。R在遇到一个变量名以后，将检查搜索路径中的数据框以定位到这个变量
  attach(nrDEG)
  x=logFC ; y=-log10(P.Value)
  png("logFC_P.png",width=500,height=500,units="px")
  plot(x , y)
  dev.off()
  library(ggpubr)
  df=nrDEG
  df$v= -log10(P.Value) #df新增加一列'v',值为-log10(P.Value)
  #绘制散点图
  dev.new()
  p<-ggscatter(df, x = "logFC", y = "v",size=0.5)
  ggsave("LogFC_v.png",p)
  dev.off()
  #再加一列判断是上调基因还是下调基因
  #if判断：如果这一基因的P.Value>0.05，则为stable基因
  #否则P.Value<0.05的基因，再if如果logFC >1,则为up（上调）基因
  #否则logFC <1 的基因，再if 判断：如果logFC <-1，则为down（下调）基因，否则为stable基因
  df$g=ifelse(df$P.Value>0.05,'stable', 
              ifelse( df$logFC >1,'up', 
                      ifelse( df$logFC < -1,'down','stable') )
  )
  table(df$g)
  df$name=rownames(df)
  head(df)
  #ggscatter(df, x = "logFC", y = "v",size=0.5,color = 'g')
  ggscatter(df, x = "logFC", y = "v", color = "g",size = 4,alpha = 0.6,
            label = "name", repel = T,
            #label.select = rownames(df)[df$g != 'stable'] ,
            label.select = head(rownames(deg)), #挑选一些基因在图中显示出来
            palette = c("#35739b", "#bdbec0", "#de3122") ) +
    coord_fixed(1) +  
    geom_hline(yintercept=-log(0.05,10), linetype="dashed") +
    geom_vline(xintercept=c(-1,1), linetype="dashed") +
    xlab("Log2(Fold Change)") + ylab("-Log10(P value)") +
    xlim(-4,4)
  ggsave('volcano.png')
  ggscatter(df, x = "AveExpr", y = "logFC",size = 0.2)
  ggsave("AveExpr_logFC.png")
  
  #ifelse函数：选择
  df$p_c = ifelse(df$P.Value<0.001,'p<0.001',
                  ifelse(df$P.Value<0.01,'0.001<p<0.01','p>0.01'))
  table(df$p_c )
  p <- ggscatter(df,x = "AveExpr", y = "logFC", color = "p_c",size=0.5, 
            palette = c("#35739b", "#de3122", "#bdbec0") )+
  coord_fixed(1) 
  ggsave('MA.png',p)
}

## for heatmap 热图
if(T){ 
  #load(file = 'step1-output.Rdata')
  experset_group[1:4,1:6]
  table(group_list)
  x=deg$logFC #deg取logFC这列并将其重新赋值给x
  names(x)=rownames(deg) #deg取probe_id这列，并将其作为名字给x
  #对x进行从小到大排列，取前100及后100，并取其对应的探针名，作为向量赋值给cg
  cg=c(names(head(sort(x),100)),
       names(tail(sort(x),100)))
  library(pheatmap)
  p<-pheatmap(experset_group[cg,],show_colnames =F,show_rownames = F) #对dat按照cg取行，所得到的矩阵来画热图
  ggsave("heatmap.png",p)
  n=t(scale(t(experset_group[cg,])))
  #通过“scale”对log-ratio数值进行归一化，现在的dat是行名为探针，列名为样本名
  #由于scale这个函数应用在不同组数据间存在差异时，需要行名为样本，因此需要用t(dat[cg,])来转换，最后再转换回来
  n[n>2]=2
  n[n< -2]= -2
  n[1:4,1:6]
  pheatmap(n,show_colnames =F,show_rownames = F)
  ac=data.frame(g=group_list)
  rownames(ac)=colnames(n) #将ac的行名也就分组信息 给到n的列名，即热图中位于上方的分组信息
  pheatmap(n,show_colnames =F,
           show_rownames = F,
           cluster_cols = F,
           color = colorRampPalette(c("#35739b", "white", "#de3122"))(50) ,
           annotation_col=ac,filename = 'heatmap_top100_DEG.png') #列名注释信息为ac即分组信息
}
write.csv(deg,file = 'degtop.csv')
sprintf("DeSeq SUCCEED %s",date());


#kegg:基因功能存储在pathway数据库里
#rm(list = ls())  
#load(file = 'deg.Rdata')
head(deg)
## 筛选阈值影响后面的超几何分布检验结果
logFC_t=1
deg=nrDEG
deg$g=ifelse(deg$P.Value>0.05,'stable',
             ifelse( deg$logFC > logFC_t,'UP',
                     ifelse( deg$logFC < -logFC_t,'DOWN','stable') )
)
table(deg$g)
head(deg)
deg$symbol=rownames(deg)

library(ggplot2)
library(clusterProfiler)
library(org.Hs.eg.db)

df <- bitr(unique(deg$symbol), fromType = "SYMBOL",
           toType = c( "ENTREZID"),
           OrgDb = org.Hs.eg.db)
dev.off(3);dev.off(4);dev.off(5)
head(df)
DEG=deg
head(DEG)
#merge函数：将两个数据集合并
#用于指定依据哪个列合并，常用于当两个数据集公共列名不一样的时候；
DEG=merge(DEG,df,by.y='SYMBOL',by.x='symbol')
head(DEG)
#标注好的差异基因
save(DEG,file = 'anno_DEG.Rdata')

gene_up= DEG[DEG$g == 'UP','ENTREZID'] 
name_up = DEG[DEG$g == 'UP', 'symbol']
gene_down=DEG[DEG$g == 'DOWN','ENTREZID'] 
gene_diff=c(gene_up,gene_down)
gene_all=as.character(DEG[ ,'ENTREZID'] )
data(geneList, package="DOSE")
head(geneList)
boxplot(geneList)
boxplot(DEG$logFC)
geneList=DEG$logFC
names(geneList)=DEG$ENTREZID
geneList=sort(geneList,decreasing = T)
write.csv(DEG,file = 'DEG.csv')

mlexpr <- t(experset_group)
#mlexpr <- experset_group
mlexpr_n=mlexpr[,name_up]
mlexpr_n <- cbind(mlexpr_n,group_list)
write.csv(mlexpr_n,file = 'mlexpr.csv')


## KEGG pathway analysis
### 做KEGG数据集超几何分布检验分析，重点在结果的可视化及生物学意义的理解。
library(org.Hs.eg.db)
library("clusterProfiler")
if(T){
  library(R.utils)
  R.utils::setOption("clusterProfiler.download.method",'auto')
  ###   over-representation test 超几何分布检验分析
  #kegg基因富集
  kk.up <- enrichKEGG(gene         = gene_up,
                      organism     = 'hsa',
                      universe     = gene_all,
                      pvalueCutoff = 0.9,
                      qvalueCutoff =0.9)
  head(kk.up)[,1:6]
  dotplot(kk.up )
  library(ggplot2)
  ggsave('kk.up.dotplot.png')
#keggplot function
  kegg_plot <- function(up_kegg,down_kegg){
    dat=rbind(up_kegg,down_kegg)
    colnames(dat)
    dat$pvalue = -log10(dat$pvalue)
    dat$pvalue = dat$pvalue * dat$group
    dat = dat[order(dat$pvalue,decreasing=F),]
    g_kegg<- ggplot(dat,aes(x=reorder(Description,order(pvalue,decreasing = F)),
                            y=pvalue,fill=group)) +
      geom_bar(stat="identity") +
      scale_fill_gradient(low="blue",high="red",guide=FALSE) +
      scale_x_discrete(name = "Pathway names") +
      scale_y_continuous(name="Log10P-value") +
      coord_flip()+ theme_bw()+ theme(plot.title= element_text(hjust = 0.5))+
      ggtitle("Pathway Enrichment")
  }
  
  #分析下调基因
  kk.down <- enrichKEGG(gene         =  gene_down,
                        organism     = 'hsa',
                        universe     = gene_all,
                        pvalueCutoff = 0.9,
                        qvalueCutoff =0.9)
  head(kk.down)[,1:6]
  dotplot(kk.down );ggsave('kk.down.dotplot.png')
  kk.diff <- enrichKEGG(gene         = gene_diff,
                        organism     = 'hsa',
                        pvalueCutoff = 0.05)
  head(kk.diff)[,1:6]
  dotplot(kk.diff );ggsave('kk.diff.dotplot.png')
  
  kegg_diff_dt <- as.data.frame(kk.diff)
  kegg_down_dt <- as.data.frame(kk.down)
  kegg_up_dt <- as.data.frame(kk.up)
  down_kegg<-kegg_down_dt[kegg_down_dt$pvalue<0.05,];  down_kegg$group=-1
  up_kegg<-kegg_up_dt[kegg_up_dt$pvalue<0.05,];  up_kegg$group=1
  g_kegg <- kegg_plot(up_kegg,down_kegg)
  ggsave("kegg.png",g_kegg)

  #kegg_up_down.png

  ###  GSEA 基因富集
  kk_gse <- gseKEGG(geneList     = geneList,
                    organism     = 'hsa',
                    nPerm        = 1000,
                    minGSSize    = 120,
                    pvalueCutoff = 0.9,
                    verbose      = FALSE)
  head(kk_gse)[,1:6]
  gseaplot(kk_gse, geneSetID = rownames(kk_gse[1,]))
  #处理数据，挑选一部分数据
  down_kegg<-kk_gse[kk_gse$pvalue<0.05 & kk_gse$enrichmentScore < 0,]
  down_kegg$group=-1
  
  up_kegg<-kk_gse[kk_gse$pvalue<0.05 & kk_gse$enrichmentScore > 0,]
  up_kegg$group=1
}

#gseaplot2用法
#library(enrichplot)
#enrichplot::gseaplot2(
#  kk_gse, #gseaResult object，即GSEA结果
#  "has04657", #富集的ID编号
#  1:4,
#  title = "GSEA", #标题
  #color = "green",#GSEA线条颜色
  #base_size = 11,#基础字体大小
  #rel_heights = c(1.5, 0.5, 1),#副图的相对高度
  #subplots = 1:3, #要显示哪些副图 如subplots=c(1,3) #只要第一和第三个图，subplots=1#只要第一个图
#  pvalue_table = T #, #是否添加 pvalue table
  #ES_geom = "line" #running enrichment score用先还是用点ES_geom = "dot"
#)


### GO database analysis 
g_list=list(gene_up=gene_up,
            gene_down=gene_down,
            gene_diff=gene_diff)
  
g_list=matrix(g_list)
  
if(T){
    go_enrich_results <- lapply( g_list , function(gene) {
      lapply(c("BP","MF","CC"), function(ont){
        cat(paste("Now process",ont))
        ego <- enrichGO(gene          = gene,
                        universe      = gene_all,
                        OrgDb         = org.Hs.eg.db,
                        ont           = ont ,
                        pAdjustMethod = "BH",
                        pvalueCutoff  = 0.99, #0.99,
                        qvalueCutoff  = 0.99,
                        readable      = TRUE)
      print( head(ego) )
      return(ego)
    })
  })
save(go_enrich_results,file = 'go_enrich_results.Rdata')

load(file = 'go_enrich_results.Rdata')
n1= c('gene_up','gene_down','gene_diff')
n2= c('BP','MF','CC') 
for (i in 1:3){
  for (j in 1:3){
    fn=paste0('dotplot_',n1[i],'_',n2[j],'.png')
    cat(paste0(fn,'\n'))
    png(fn,res=150,width = 1080)
    print( dotplot(go_enrich_results[[i]][[j]] , label_format=100))
    dev.off()
  }
}
}

#View(kegg_down_dt)
#browseKEGG(kk.down, 'hsa00980') #网页查看通路

### cnetplot: Gene-Concept Network
#构建含log2FC信息的genelist 
library("ggnewscale")
genelist <- as.numeric(deg[,1]) 
names(genelist) <- row.names(deg)
cnetp1 <- cnetplot(go_enrich_results[[2]][[3]],  foldChange = genelist,
                   showCategory = 6,
                   colorEdge = T,
                   node_label = 'all',
                   color_category ='steelblue')
cnetp2 <- cnetplot(go_enrich_results[[2]][[3]],  foldChange = genelist,
                   showCategory = 6,
                   node_label = 'gene',
                   circular = T, 
                   colorEdge = T)
ggsave(cnetp1,filename ='cnetplot_down_bp.pdf', width =12,height =10)
ggsave(cnetp2,filename = 'cnetplot_cir_down_bp.jpg', width =15,height =10)

#ROC
roc <- dplyr::filter(experset_groupL, grepl('AKR1C3', probe))


