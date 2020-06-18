#!/bin/bash -u


PLOT_FILE=plot-hist.png
DATA_FILE=/tmp/plot-hist.$RANDOM.data

DEBUG=false
RM_OUTLIERS=false
N_BINS=
XLABEL=
LOGY=false
BOXWIDTH=1
iC=0
for i in "$@"
do
  iC=$(( iC+1 ))
  case $i in 
    -f=*) #define the file with the data
      cp ${i/-f=} $DATA_FILE 
    ;;
    -d) #define the histogram data as blank-separated list of values and all arguments after this one are assumed to be the histogram values
      shift
      for j in ${@:$iC}
      do
        echo "$j"
      done | sort -g > $DATA_FILE
      break
    ;;
    -d=*) #define the histogram data as a comma-separated list of values, with no blanks
      printf "%s\n" ${i//,/ } | sort -g > $DATA_FILE
    ;;
    modes) #shows all available modes and exit
      grep ') #' $BASH_SOURCE \
        | grep -v grep \
        | sed 's:)::g' \
        | column -t -s\#
      exit
    ;;
    -x) #set -x bash option
      set -x
    ;;
    -o=*) #define the name of the histogram plot file
      PLOT_FILE=${i/-o=} 
    ;;
    --debug|debug) #show some debug output
      DEBUG=true 
    ;;
    --rm-outliers) #remove outliers before plotting
      RM_OUTLIERS=true
    ;;
    --n-bins=*) #specify the number of bins
      N_BINS=${i/--n-bins=}
    ;;
    --x-label=*) #specify the x-axis label
      XLABEL=${i/--x-label=}
    ;;
    --log-y) #use logarithmic scale in the y-axis 
      LOGY=true
    ;;
    --box-width=*) #define the width factor of the histogram bars, 1 means the bars have no gaps between them
      BOXWIDTH=${i/--box-width=}
    ;; 
    help|-h) #show the help string and exit
      echo "\
Plot the histogram of a set of values. Usage:

$BASH_SOURCE -f=<data file> [ <options> ]>
$BASH_SOURCE -d=<value 1>,<value 2>,...,<value N> [ <options> ]
$BASH_SOURCE [ <options> ] -d <value 1> <value 2> ... <value N>

All options:"
      $BASH_SOURCE modes
      exit 
    ;;
  esac
done

if [ ! -e $DATA_FILE ]
then
  echo -e "ERROR: need one of -f= or -d= or -d input arguments:\n"
  $BASH_SOURCE help
  exit
fi

#sorting and using gnuplot number formatting
cat $DATA_FILE | \
  awk '{ printf("%.3g\n",$1)}' | \
  sort -g > $DATA_FILE.tmp && \
  mv -f $DATA_FILE.tmp $DATA_FILE

#remove outliers if asked
if $RM_OUTLIERS
then
  cat $DATA_FILE | awk '
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
    if ( v[i]!=0) printf("%.3g\n",v[i]) 
  }
}' | \
  sort -g > $DATA_FILE.tmp && \
  mv -f $DATA_FILE.tmp $DATA_FILE
fi

#getting plot parameters
min=`head -n1 $DATA_FILE`
max=`tail -n1 $DATA_FILE`
n=`cat $DATA_FILE | wc -l | sed 's: ::g'`
case "$N_BINS" in
  ""|simple)
    n_bins=`echo "sqrt($n)" | bc`
  ;;
  # https://en.wikipedia.org/wiki/Freedman–Diaconis_rule
  Freedman-Diaconis|FD)
    echo "ERROR: implementation needed"
  ;;
  *)
    n_bins=$N_BINS
  ;;
esac
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
# set xrange [min-(max-min)*0.05:max+(max-min)*0.05]
$($LOGY || echo "set yrange [0:]")
#to put an empty boundary around the
#data inside an autoscaled graph.
# set offset graph 0.05,0.05,0.05,0.0
# set xtics min,(max-min)/5,max
set boxwidth width*$BOXWIDTH
set style fill solid 0.5	#fillstyle
set format x "%.2g"
set tics out nomirror
$([ -z "$XLABEL" ] || echo "set xlabel \"$XLABEL\"")
set ylabel "count"
$($LOGY && echo "set logscale y")
set title "$title" 
#count and plot
plot "$DATA_FILE" u (hist(\$1,width)):(1.0) smooth freq w boxes lc rgb"gray" notitle
%

$DEBUG || rm -f $DATA_FILE