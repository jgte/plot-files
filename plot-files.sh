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

#parameters
FONT="arial,16"
XDATA_FORMAT="%Y-%m-%d"
PLOT_DATE_FORMAT="%Y-%m-%d"
POINTSIZE=0.5
MAX_POINTSIZE=2
XTICKS="float"
TERMINAL=pngcairo #also used for file extension (try jpeg, fig, gif, svg, tikz, etc)
SIZE="1200,900"
DISPLAY_FLAG=false
INTERACTIVE=false
FILE_LIST=()
LABELS=
TITLE=
OUT=
OUTDIR=
FILE_LABELS=
QUIET=false
DEBUG=false
XDATA_INTEGER=false
LOGY=false
LOGX=false
START=
LEN=
DYNPS=false
FORCE=false
XLABEL=
YLABEL=
DEMEAN=false
YRANGE=
XRANGE=
SET_KEY=default
PLOT_STYLE=linespoints
POINT_STYLE=1
SHORELINE=$(cd $(dirname $BASH_SOURCE);pwd)/Shoreline_Data.txt
while [[ $# -gt 0 ]]
do
  case "$1" in
  -x) #set -x bash option
    set -x
  ;;
  --files|-f)
    # https://stackoverflow.com/a/918931/2047215
    shift; IFS=',' read -ra FILE_LIST <<< "$1"
  ;;
  --filelabels|-F) #label for the data files, comma-separated and use 'null' to suppress that legend entry
    shift; IFS=',' read -ra FILE_LABELS <<< "$1"
    for ((i=0;i<${#FILE_LABELS[@]};i++))
    do
      [ "${FILE_LABELS[i]}" == "null" ] && FILE_LABELS[i]=''
    done
  ;;
  --labels|-b) #comma-separated list of labels for the data columns; use 'null' to suppress that legend entry but still plot the data; use '-' to skip plotting that column; use 't' to set that column as the free variable, i.e. the x-axis; use 'lat' and 'lon' to define the latitude and longitude of the points to plot
    shift; IFS=',' read -ra LABELS <<< "$1"
    for ((i=0;i<${#LABELS[@]};i++))
    do
      [ "${LABELS[i]}" == "null" ] && LABELS[i]=''
    done
  ;;
  --out|-o) #name of plot file, defaults to first data file, the plot is extension added automaticall, if needed
    shift; OUT="$1"
  ;;
  --outdir) #save plot file to this dir; this can also be specified in -out but this option is used in containers to ensure the file is saved to a mounted dir; overrides the path of the file specified in --out
    shift; OUTDIR="$1"
  ;;
  --display) #shows the plot after writing the output file
    DISPLAY_FLAG=true
  ;;
  --interactive) #do not produce the output file but show it in x11
    INTERACTIVE=true
  ;;
  --quiet) #limit the user feedback
    QUIET=true
  ;;
  --debug|-D) #show debug info during execution
    DEBUG=true
  ;;
  --force) #delete plot file, if existing; by default no replotting is done
    FORCE=true
  ;;
  --title|-T) #set the title explicitly
    shift; TITLE="$1"
  ;;
  --xticks) #use special formating in the x-axis ticks: dates, float, integer, scientific, defaults to float
    shift; XTICKS="$1"
  ;;
  --x-date-data) #speficy the format of the dates in the data file/files, defaults to %Y-%m-%d
    shift; XDATA_FORMAT="$1"
  ;;
  --x-date-format|-q) #speficy the format of the dates in the x-axis, defaults to %Y-%m-%d
    shift; PLOT_DATE_FORMAT="$1"
  ;;
  --logy|-l) #use logarithmic y-axis scale and plot absolute values
    LOGY=true
  ;;
  --logx) #use logarithmic x-axis scale
    LOGX=true
  ;;
  --start-x|-s) #plot only from this line onwards
    shift; START="$1"
  ;;
  --end-x|-e) #plot only unit this line; this argument must come after --start-x
    shift; LEN=$(( $1-START+1))
  ;;
  --len) #plot only this number of lines
    shift; LEN="$1"
  ;;
  --point-size) #marker size, defaults to 0.5
    shift; POINTSIZE="$1"
  ;;
  --dyn-point-size) #increase marker size for each additional line
    DYNPS=true
  ;;
  --max-point-size) #maximum size of markers when dyn-point-size, defaults to 2
    shift; MAX_POINTSIZE="$1"
  ;;
  --font) #font type and size, defaults to 'arial,16'
    shift; FONT="$1"
  ;;
  --x-label|-X) #define x-axis label, defaults to none
    shift; XLABEL="$1"
  ;;
  --y-label|-Y) #define y-axis label, defaults to none
    shift; YLABEL="$1"
  ;;
  --demean) #remove the mean of all columns before plotting
    DEMEAN=true
  ;;
  --terminal) #set the gnuplot terminal type, defaults to pngcairo
    shift; TERMINAL="$1"
  ;;
  --size) #set the terminal size, defaults to 1200,900
    shift; SIZE="$1"
  ;;
  --y-range) #sets the limit of the y-axis range, defaults set whatever is set by gnuplot
    shift;  YRANGE="$1"
    if [[ "${YRANGE/:}" == "$YRANGE" ]]
    then
      echo "ERROR: input --y-range=... must contain the character ':' separating the min and max values of the y-axis range."
      exit 3
    fi
  ;;
  --x-range) #sets the limit of the x-axis range, defaults set whatever is set by gnuplot
    shift;  XRANGE="$1"
    if [[ "${XRANGE/:}" == "$XRANGE" ]]
    then
      echo "ERROR: input --x-range=... must contain the character ':' separating the min and max values of the x-axis range."
      exit 3
    fi
  ;;
  --set-key) #sets location of the legend; one of left, right, top, bottom, center, inside, outside, lmargin, rmargin, tmargin, bmargin
    shift
    SET_KEY="${1//_/ }"
  ;;
  --plot-style) #sets the plot style; one of lines, points, linespoints, impulses, dots, steps, errorbars, yerrorbars, xerrorbars, xyerrorbars, boxes, boxerrorbars, or boxxyerrorbars
    shift
    PLOT_STYLE="$1"
  ;;
  --point-style) #sets the marker style for the first file, given as an integer number, see http://www.gnuplotting.org/doc/ps_symbols.pdf
    shift
    POINT_STYLE="$1"
  ;;
  --shoreline) #define this file as defining the shore lines in lat/lon plots, defaults to ./Shoreline_Data.txt
    shift
    SHORELINE="$1"
  ;;
  --arguments) #list all arguments and exits
    grep ') #' $BASH_SOURCE \
      | grep -v grep \
      | sed 's:)::g' \
      | column -t -s\#
    exit
  ;;
  --help|-h) #shows the help screen
    echo "Plots one or more column data files. Be sure to checkout http://www.gnuplot.info/docs_4.0/gpcard.pdf

Mandatory arguments:
--files <data file1>[,<data file2>[,...]] : files with data in column-wise format
--labels [t,][-,]column1label[,column2label[,...]], with meaning:
  t            : abcissa (can handle dates in common formats)
  -            : ignore this column
  columnXlabel : label to give to the column in this data

Optional arguments  :"
    $BASH_SOURCE --arguments
    exit 0
  ;;
  *)
    echo "WARNING: ignoring argument '$1'"
  ;;
  esac
  shift
done

if [ "${LABELS:-x}" == "x" ]
then
  echo "ERROR: need --labels and --files arguments"
  $BASH_SOURCE --help
  exit 3
fi

if [ ${#FILE_LIST[@]} -lt 1 ]
then
  echo "ERROR: need valid file name(s) as argument(s)"
  $BASH_SOURCE --help
  exit 3
fi

if [ -z "$FILE_LABELS" ]
then
  FILE_LABELS=()
  if [ ${#FILE_LIST[@]} -gt 1 ]
  then
    for ((f=0;f<${#FILE_LIST[@]};f++))
    do
      FILE_LABELS+=($(basename ${FILE_LIST[f]}))
    done
  else
    FILE_LABELS+=(' ')
  fi
fi

# https://serverfault.com/questions/133692/how-to-display-certain-lines-from-a-text-file-in-linux
# middle() { local s=$1; local COL=$2; shift 2; sed -n "$s,$(( s+COL-1 ))p; $(( s+COL ))q" "$@"; }
middle() { sed -n ''$1',+'$2'p' $3; }

if [ ! -z "$START" ] || [ ! -z "$LEN" ]
then
  echo "Slicing files from $START with length $LEN:"
  [ -z "$START" ] && START=1
  for ((f=0;f<${#FILE_LIST[@]};f++))
  do
    $DEBUG && echo ${FILE_LIST[f]}
    FILE_LEN=$(cat ${FILE_LIST[f]} | wc -l)
    $DEBUG && echo "file      length : $FILE_LEN"
    if [ -z "$LEN" ]
    then
      LEN_NOW=$(( FILE_LEN - START +1 ))
      $DEBUG && echo "computed  length : $LEN_NOW"
    else
      LEN_NOW=$LEN
      $DEBUG && echo "requested length : $LEN_NOW"
    fi
    #get section from original file and put it in temp file
    TMPFILE=/tmp/$(basename $BASH_SOURCE).$RANDOM.$RANDOM
    middle $START $LEN ${FILE_LIST[f]} > $TMPFILE
    $DEBUG && echo "actual    length : $(cat $TMPFILE | wc -l)"
    FILE_LIST[f]=$TMPFILE
  done
fi

#retrieve expected extension
EXT=$(extension $TERMINAL)
#resolving output file name
if [ -z "$OUT" ]
then
  #if no -out= was given, make up something
  OUT=${FILE_LIST[0]}
else
  #out was given, add extension (if needed)
  OUT=${OUT%\.$EXT}.$EXT
fi
#if an outdir was given, prepend it to basename of out
[ -z "$OUTDIR" ] || OUT=$OUTDIR/$(basename $OUT)

#enforce force
$FORCE && rm -f $OUT
#skip if plot is already available
if [ -s "$OUT" ]
then
 echo "plot $OUT already available, skipping..."
 exit
fi

$QUIET \
  || echo "\
Plotting the following ${#FILE_LIST[@]} files:
$(printf '%s\n' "${FILE_LIST[@]}")
file labels : ${FILE_LABELS[@]:-} (${#FILE_LABELS[@]} entries)
labels      : ${LABELS[@]} (${#LABELS[@]} entries)
out         : $OUT
out dir     : $OUTDIR
display     : $DISPLAY_FLAG
interactive : $INTERACTIVE
debug       : $DEBUG
force       : $FORCE
title       : $TITLE
xticks      : $XTICKS
x-date-data : $XDATA_FORMAT
x-date-format : $PLOT_DATE_FORMAT
logy        : $LOGY
logx        : $LOGX
start-x     : $START
len         : $LEN
point-size  : $POINTSIZE
dyn-point-size : $DYNPS
max-point-size : $MAX_POINTSIZE
font        : $FONT
xlabel      : $XLABEL
ylabel      : $YLABEL
demean      : $DEMEAN
terminal    : $TERMINAL
size        : $SIZE
yrange      : $YRANGE
xrange      : $XRANGE
set-key     : $SET_KEY
plot-style  : $PLOT_STYLE
point-style : $POINT_STYLE
shoreline   : $SHORELINE"

#determine xdata column
XDATA=
LAT=
LON=
COL=0
NR_COL=0
for i in ${LABELS[@]}
do
  COL=$((COL+1))
  case $i in
  "t")
    XDATA=$COL
    $QUIET || echo "x-data   is  in   column $COL"
  ;;
  "-")
    $DEBUG && echo "ignoring  data in column $COL"
  ;;
  "lat")
    LAT=$COL
    $QUIET || echo "latitude  data in column $COL"
  ;;
  "lon")
    LON=$COL
    $QUIET || echo "longitude data in column $COL"
  ;;
  *)
    NR_COL=$((NR_COL+1))
    $QUIET || echo "plotting  data in column $COL"
  ;;
  esac
done

#sanity and set the LATLON flag
if [ ! -z "$LAT" ] && [ ! -z "$LON" ]
then
  $DEBUG && echo "Producing latitude and longitude plot with domain defined in columns $LAT and $LON, respectively"
  LATLON=true
  [ "$SET_KEY" == "default" ] && SET_KEY="outside bottom center"
  echo "SET_KEY=$SET_KEY"
  # [ -z "$XLABEL" ] && XLABEL="longitude [deg]"
  # [ -z "$YLABEL" ] && YLABEL="latitude [deg]"
elif [ ! -z "$LAT" ] || [ ! -z "$LON" ]
then
  echo "ERROR: in the comma-separated list of columns in -labels=..., if one entry is 'lat', then also need another entry to be 'lon'"
  exit 3
elif [ -z "$XDATA" ]
then
  echo "ERROR: need one entry in the comma-separated list of columns in -labels=... to be 't'"
  exit 3
else
  LATLON=false
fi

#init gnuplot formatting commands
FMT_CMD=()

#enfore logx/y if requested
$LOGY && ! $LATLON && FMT_CMD+=(
  "set logscale y 10"
  "set format y \"%5.0e\""
)
$LOGX && ! $LATLON && FMT_CMD+=(
  "set logscale x 10"
)
#by default, expect x data to be numeric values
XDATA_CMD="(\$$XDATA)"
#enforce date format if requested
if ! $LATLON
then
  case $XTICKS in
    d*)
      FMT_CMD+=(
        "set xdata time"
        "set timefmt \"$XDATA_FORMAT\""
        "set format x \"$PLOT_DATE_FORMAT\""
      )
      #do not use numeric convertion for x data (set by default above)
      XDATA_CMD=$XDATA
    ;;
    f*)
      FMT_CMD+=("set format x \"%f\"")
    ;;
    i*)
      FMT_CMD+=("set format x \"%.0f\"")
    ;;
    s*)
      FMT_CMD+=("set format x \"%e\"")
    ;;
    *)
      echo "ERROR: cannot handle value '$XTICKS' of argument -xticks="
      exit 3
    ;;
  esac
else
  if [ ! "$XTICKS" == "float" ]
  then
    echo "WARNING: ignoring --xticks with value '$XTICKS'"
  fi
fi

#enforce requested y-axis range
if [ ! -z "$YRANGE" ]
then
  FMT_CMD+=(
    "set yrange [$YRANGE]"
  )
elif $LATLON
then
  FMT_CMD+=(
    "set yrange [-90:90]"
  )
fi

#enforce requested x-axis range
if [ ! -z "$XRANGE" ]
then
  FMT_CMD+=(
    "set xrange [$XRANGE]"
  )
elif $LATLON
then
  FMT_CMD+=(
    "set xrange [0:360]"
  )
fi

#init gnuplot plot command
PLOT_ARGS=()
#file column index
COL=0
#plot line index (used for consistent coloring)
c=0
for i in "${LABELS[@]}"
do
  COL=$((COL+1))
  case $i in
  "t"|"-"|"lat"|"lon")
    #do nothing
  ;;
  err)
    #reset file-wise color if there's only one data column
    [ $NR_COL -eq 1 ] && c=1
    cp=$((COL-1))
    for ((f=0;f<${#FILE_LIST[@]};f++))
    do
      #OFFSET and LEGEND were defined in previous iteration
      PLOT_ARGS+=("'${FILE_LIST[f]}' using $XDATA_CMD:(\$$cp - $OFFSET - \$$COL/2) with $PLOT_STYLE pointsize 0 lw 1 lc $c title '${LEGEND/ ?$OFFSET} - sigma'")
      PLOT_ARGS+=("'${FILE_LIST[f]}' using $XDATA_CMD:(\$$cp - $OFFSET + \$$COL/2) with $PLOT_STYLE pointsize 0 lw 1 lc $c title '${LEGEND/ ?$OFFSET} + sigma'")
      #increment file-wise color if there's only one column
      [ $NR_COL -eq 1 ] && c=$((c+1))
    done
  ;;
  *)
    if $LATLON
    then
      for ((f=0;f<${#FILE_LIST[@]};f++))
      do
        if $DEMEAN
        then
          #compute the mean
          OFFSET=$(awk '{total+=$'$COL'} END {printf "%g",total/NR}' ${FILE_LIST[f]})
          #append it to title
          LEGEND+=" $OFFSET"
        fi
        PLOT_ARGS+=("'${FILE_LIST[f]}' using $LON:$LAT:(\$$COL - $OFFSET) title '$LEGEND' with $PLOT_STYLE pointtype $((f+$POINT_STYLE)) pointsize $POINTSIZE lc palette")
      done
    else
      #reset file-wise color if there's only one data column
      [ $NR_COL -eq 1 ] && c=1 || c=$((c+1))
      for ((f=0;f<${#FILE_LIST[@]};f++))
      do
        $DYNPS && PS=$(echo "scale=1;($N-$i)/$N*($MAX_POINTSIZE-$POINTSIZE)+$POINTSIZE"|bc) || PS=$POINTSIZE
        OFFSET=0
        LEGEND="$i ${FILE_LABELS[f]}"
        if $DEMEAN
        then
          #compute the mean
          OFFSET=$(awk '{total+=$'$COL'} END {printf "%g",total/NR}' ${FILE_LIST[f]})
          #append it to title
          LEGEND+=" $OFFSET"
        fi
        PLOT_ARGS+=("'${FILE_LIST[f]}' using $XDATA_CMD:(\$$COL - $OFFSET) title '$LEGEND' with $PLOT_STYLE pointtype $((f+$POINT_STYLE)) pointsize $PS lw 2 lc $c")
        #increment file-wise color if there's only one column
        [ $NR_COL -eq 1 ] && c=$((c+1))
      done
    fi
  ;;
  esac
done

$LATLON && PLOT_ARGS+=("\"${SHORELINE}\" u 1:2 w l lt -1 lw 1 notitle" )

PLOT_CMD="\
set autoscale
set xtic auto
set ytic auto
set grid
set title \"$TITLE\"
set xlabel \"$XLABEL\"
set ylabel \"$YLABEL\"
set mouse mouseformat \"%f,%g\"
$(printf '%s\n' "${FMT_CMD[@]:-}")
set key $SET_KEY
"
# https://github.com/Gnuplotting/gnuplot-palettes/blob/master/rdylbu.pal
$LATLON && PLOT_CMD+="\
# palette
set palette defined (\\
1  '#67001f',\\
2  '#b2182b',\\
3  '#d6604d',\\
4  '#f4a582',\\
5  '#fddbc7',\\
6  '#f7f7f7',\\
7  '#d1e5f0',\\
8  '#92c5de',\\
9  '#4393c3',\\
10 '#2166ac',\\
11 '#053061')
"
PLOT_CMD+="plot $(printf '%s,' "${PLOT_ARGS[@]:-}")"

#user feedback
$DEBUG && echo "gnuplot cmd : $PLOT_CMD"

if $INTERACTIVE
then
# https://superuser.com/questions/1096831/start-an-interactive-session-in-gnuplot-and-execute-some-commands-when-it-opens
prmpt () { (echo -n "gnuplot> " >&2) }
gnuplotInPipe () {
  echo "
set terminal x11 size $SIZE font \"$FONT\"
$PLOT_CMD"
  (echo "Type 'quit' to exit" >&2)
  prmpt
  while true; do
    read -er cmd
    if [ "$cmd" == 'quit' ]; then
      break
    fi
    echo "$cmd"
    prmpt
  done
}
gnuplotInPipe $1 | gnuplot
else

[ -d $(dirname "$OUT") ] || mkdir -p $(dirname "$OUT")
[ -e "$OUT" ] || gnuplot <<%
set terminal $TERMINAL size $SIZE font "$FONT" $([[ ! "${TERMINAL/cairo}" == "$TERMINAL" ]] && echo enhanced)
set output "$OUT"
$PLOT_CMD
%

$DISPLAY_FLAG && display "$OUT" || echo "plotted $OUT"

fi

#cleanup
if [ ! -z "$START" ] || [ ! -z "$LEN" ]
then
  rm -f /tmp/$(basename $BASH_SOURCE)*
fi