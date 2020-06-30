#!/bin/bash -u

function extension()
{
  local OUT="$1"
  for i in cairo latex
  do
    [ "$1" == "$i" ] || OUT=${OUT/$i}
  done
  echo "$OUT"
}

DATA_FILE=/tmp/plot-hist.$RANDOM.data
TITLE=
OUT=plot-hist.png
OUTDIR=
DEBUG=false
RM_OUTLIERS=false
N_BINS=
FORCE=false
XLABEL=
LOGY=false
BOXWIDTH=1
TERMINAL=pngcairo #also used for file extension (try jpeg, fig, gif, svg, tikz, etc)
SIZE="1200,900"
FONT="arial,16"

iC=0
while [[ $# -gt 0 ]]
do
  iC=$(( iC+1 ))
  case "$1" in 
    -x) #set -x bash option
      set -x
    ;;
    --files|-f) #define the file with the data
      shift; cat "$1" | sort -g > $DATA_FILE 
    ;;
    --bsv-data) #define the histogram data as list of blank-separated values (bsv) and all arguments after this one are assumed to be the histogram values
      shift
      for j in ${@:$iC}
      do
        echo "$j"
      done | sort -g > $DATA_FILE
      break
    ;;
    --csv-data) #define the histogram data as a list of comma-separated values (csv), with no blanks
      shift; printf "%s\n" "${1//,/ }" | sort -g > $DATA_FILE
    ;;
    --title|-T) #set the title explicitly
      shift; TITLE="$1"
    ;;
    --out|-o) #define the name and path of the histogram plot file
      shift; OUT="$1"
    ;;
    --outdir) #define the path of the histogram plot file, overwrites the path in -out=
      shift; OUTDIR="$1"
    ;;
    --debug|-D) #show some debug output
      DEBUG=true 
    ;;
    --force) #delete plot file, if existing; by default no replotting is done
      FORCE=true           
    ;;
    --rm-outliers) #remove outliers before plotting
      RM_OUTLIERS=true
    ;;
    --n-bins) #specify the number of bins
      shift; N_BINS="$1"
    ;;
    --x-label|-X) #specify the x-axis label
      shift; XLABEL="$1"
    ;;
    --logy|-l) #use logarithmic scale in the y-axis 
      LOGY=true
    ;;
    --box-width) #define the width factor of the histogram bars, 1 means the bars have no gaps between them
      shift; BOXWIDTH="$1"
    ;; 
    --terminal) #set the gnuplot terminal type, defaults to pngcairo
      shift; TERMINAL="$1"
    ;;
    --size) #set the terminal size, defaults to 1200,900
      shift; SIZE="$1"
    ;;
    --font) #font type and size, defaults to 'arial,16'
      shift; FONT="$1"
    ;;
    --arguments) #shows all available modes and exit
      grep ') #' $BASH_SOURCE \
        | grep -v grep \
        | sed 's:)::g' \
        | column -t -s\#
      exit
    ;;
    --help|-h) #show the help string and exit
      echo "\
Plot the histogram of a set of values. Usage:

$BASH_SOURCE -f <data file> [ <options> ]
$BASH_SOURCE --csv-data <value 1>,<value 2>,...,<value N> [ <options> ]
$BASH_SOURCE [ <options> ] --bsv-data <value 1> <value 2> ... <value N>

Note that the <data file> should only contain one column of data. For files with multiple columns, bash provides good solutions, e.g. to plot the third column of data.file:

$BASH_SOURCE -f <(awk '{print \$3}' data.file) [ <options> ]

All options:"
      $BASH_SOURCE --arguments
      exit 
    ;;
    *)
      echo "WARNING: ignoring argument '$1'"
    ;;
  esac
  shift
done

if [ ! -e $DATA_FILE ]
then
  echo -e "ERROR: need one of --files, --bsv-data or --csv-data:\n"
  $BASH_SOURCE --help
  exit
fi

#retrieve expected extension
EXT=$(extension $TERMINAL)
#out was given, add extension (if needed)
OUT=${OUT%\.$EXT}.$EXT
#if an outdir was given, prepend it to basename of out
[ -z "$OUTDIR" ] || OUT=$OUTDIR/$(basename $OUT)

#enforce force
$FORCE && rm -f $OUT

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
[ -z "$TITLE" ] && TITLE="data points=$n, sum=$(
cat $DATA_FILE | awk '{ SUM += $1} END { printf("%g",SUM) }'
)"

$DEBUG && echo "\
Input arguments:
files       : $DATA_FILE
title       : $TITLE
out         : $OUT
outdir      : $OUTDIR
rm-outliers : $($RM_OUTLIERS && echo true || echo false)
n-bins      : $n_bins
x-label     : $XLABEL
logy        : $($LOGY && echo true || echo false)
box-width   : $BOXWIDTH
terminal    : $TERMINAL
size        : $SIZE
font        : $FONT

Some internal parameters:
min    : $min
max    : $max
n      : $n
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
set terminal $TERMINAL size $SIZE font "$FONT" $([[ ! "${TERMINAL/cairo}" == "$TERMINAL" ]] && echo enhanced)
set output "$OUT"
# set xrange [min-(max-min)*0.05:max+(max-min)*0.05]
set yrange [0:]
set boxwidth width*$BOXWIDTH
set style fill solid 0.5	#fillstyle
set format x "%.2g"
set tics out nomirror
$([ -z "$XLABEL" ] || echo "set xlabel \"$XLABEL\"")
set ylabel "count"
$($LOGY && echo "set logscale y")
set title "$TITLE" 
#count and plot
plot "$DATA_FILE" u (hist(\$1,width)):(1.0) smooth freq w boxes lc rgb"gray" notitle
%

echo "plotted $OUT"

$DEBUG || rm -f $DATA_FILE