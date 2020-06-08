#!/bin/bash -u


PLOT_FILE=plot-hist.png
DATA_FILE=/tmp/plot-hist.$RANDOM.data

if [ $# -lt 1 ]
then
  $BASH_SOURCE help
  echo "ERROR:Need at least one input argument."
  exit 3
fi

DEBUG=false
RM_OUTLIERS=false
for i in "$@"
do
  case $i in 
    -x) set -x;;
    -f=*) cp ${i/-f=} $DATA_FILE ;;
    -o=*) PLOT_FILE=${i/-o=} ;;
    --debug) DEBUG=true ;;
    -d)
      shift
      for j in $@
      do
        echo "$j"
      done | sort -g > $DATA_FILE
      break
    ;;
    -d=*)
      printf "%s\n" ${i//,/ } | sort -g > $DATA_FILE
    ;;
    --rm-outliers)
      RM_OUTLIERS=true
    ;;
    help|-h)
      echo "\
Plot the histogram of a set of value. Usage:

$BASH_SOURCE -f=<data file> [ -o=<plot filename (defaults to '$PLOT_FILE') ]>
$BASH_SOURCE -d=<value 1>,<value 2>,...,<value N> [ -o=<plot filename (defaults to '$PLOT_FILE') ]
$BASH_SOURCE -d <value 1> <value 2> ... <value N>"
    ;;
  esac
done

#sorting and using gnuplot number formatting
cat $DATA_FILE | \
  awk '{ printf("%.3g\n",$1)}' | \
  sort -g > $DATA_FILE.tmp && \
  mv -f $DATA_FILE.tmp $DATA_FILE

#remove outliers if asked
if $RM_OUTLIERS
then
  awk '
function alen(arr, i,c) {
  c = 0
  for(i in arr) c++
  return c
}
function mean(arr, sum,c,i){
  sum=0;c=0;
  for (i in arr) { sum+=arr[i]; c++; }
  return sum/c
}
function std(arr, sum2,c,i){
  sum=0;sum2=0;c=0;
  for (i in arr) { sum+=arr[i];sum2+=arr[i]*arr[i]; c++; }
  return sqrt(sum2/c - ((sum/c)^2))
}
{
  #load the data: always the first column (no exceptions)
  v[NR-1]=$1;
} END {
  sigma=3; n_iter=5;
  for (j=0; j<n_iter; j++){
    m=mean(v);s=std(v);l=alen(v);
    for (i=0; i<l; i++) {
      if ( v[i]<m-sigma*s || v[i]>m+sigma*s ) {
        v[i]=0;
      }
    }
  }
  for (i=0; i<l; i++) {
    print v[i]
  }
}' $DATA_FILE > $DATA_FILE.tmp
  mv -f $DATA_FILE.tmp $DATA_FILE
fi

#getting plot parameters
min=`head -n1 $DATA_FILE`
max=`tail -n1 $DATA_FILE`
n=`cat $DATA_FILE | wc -l | sed 's: ::g'`
n_bins=`echo "sqrt($n)" | bc`
title="data points=$n, sum=$(
cat $DATA_FILE | awk '{ SUM += $1} END { printf("%g",SUM) }'
)"

$DEBUG && echo "\
data   : $DATA_FILE
plot   : $PLOT_FILE
min    : $min
max    : $max
n      : $n
n_bins : $n_bins
title  : '$title'
w/bin  : $(echo "$max $min $n_bins" | awk '{print ($1-$2)/$3}')
x_min  : $(echo "$max $min" | awk '{print $2-($1-$2)*0.05}')
x_max  : $(echo "$max $min" | awk '{print $1-($1-$2)*0.05}')
xtics  : $(echo "$max $min" | awk '{print ($1-$2)/5}')
"

gnuplot <<%
reset
n_bins=$n_bins	#number of intervals
max=$max	#max value
min=$min	#min value
width=(max-min)/n_bins	#interval width
#function used to map a value to the intervals
hist(x,width)=width*(floor(x/width)+0.5)
set term png	#output terminal and file
set output "$PLOT_FILE"
set xrange [min-(max-min)*0.05:max+(max-min)*0.05]
set yrange [0:]
#to put an empty boundary around the
#data inside an autoscaled graph.
# set offset graph 0.05,0.05,0.05,0.0
# set xtics min,(max-min)/5,max
set boxwidth width*0.9
set style fill solid 0.5	#fillstyle
set format x "%.2g"
set tics out nomirror
# set xlabel "x"
set ylabel "count"
set title "$title" 
#count and plot
plot "$DATA_FILE" u (hist(\$1,width)):(1.0) smooth freq w boxes lc rgb"gray" notitle
%

# gnome-open $PLOT_FILE
rm -f $DATA_FILE