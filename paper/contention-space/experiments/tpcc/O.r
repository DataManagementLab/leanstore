source("../common.r", local = TRUE)
setwd("../tpcc")
# TPC-C Out of memory (O)

dev.set(0)
df=read.csv('./O_long_stats.csv')
df=sqldf("select * from df where t >0 and tpcc_warehouse_count=10000 and c_pp_threads=4")
df=sqldf(c("update df set c_cm_split=0", "select * from main.df"))
d= sqldf("
select *, 1 as symbol from df where c_su_merge=0 and c_cm_split=0
UNION select *, 2 as symbol from df where c_su_merge=0 and c_cm_split=1
UNION select *, 3 as symbol from df where c_su_merge=1 and c_cm_split=0
UNION select *, 4 as symbol from df where c_su_merge=1 and c_cm_split=1
")


d=read.csv('./O.csv')
dev.set(0)
g <- ggplot(d, aes(t, tx, color=factor(symbol), group=factor(symbol))) +
    geom_point(aes(shape=factor(symbol)), alpha=0.5, size = 0.25) +
    scale_size_identity(name=NULL) +
    labs(x='Time [sec]', y = 'TPC-C throughput [txns/sec]') +
    geom_smooth(method ="auto", se=FALSE) +
    scale_color_manual(guide=FALSE, breaks=c(1,3), values=c("black", "#619CFF"))+
    scale_shape_discrete(guide=FALSE)+
    theme_acm +
    expand_limits(x=0,y=0) +
    annotate("text", x=1400, y=30000, label="Baseline", color ="black", size = 2) +
    annotate("text", x=1450, y=55000, label="+XMerge", color = "#619CFF", size = 2)
g
ggsave('../../tex/figures/tpcc_O.pdf', width=3 , height = 1.75, units="in")

#CairoPDF("../../tex/figures/tpcc_O.pdf", bg="transparent", width=3, height=1.75)
#print(g)
#dev.off()


ggplot(d, aes (t, (w_mib)/tx, color=factor(symbol))) + geom_smooth() + expand_limits(y=0) + facet_grid(rows=vars(tpcc_warehouse_count))
dev.new()
ggplot(d, aes (t, (r_mib)/tx, color=factor(symbol))) + geom_smooth() + expand_limits(y=0) + facet_grid(rows=vars(tpcc_warehouse_count))

stats=read.csv('./C_stats.csv')
dts=read.csv('./C_dts.csv')

dts=sqldf("select * from stats where tpcc_warehouse_count=10000 and c_su_merge=false")

combined=sqldf("select d.*, s.tpcc_warehouse_count, s.c_su_merge from dts d, stats s where s.c_hash = d.c_hash")

sqldf("select dt_name, c_hash, max(dt_misses_counter) from merge group by c_hash, dt_name")

ggplot(dts, aes(t, dt_misses_counter)) + geom_line() + facet_grid (row=vars(dt_name), col=vars()) + scale_y_log10()
