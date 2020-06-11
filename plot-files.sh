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

HELPSTR="
Plots one or more column data files.

Mandatory arguments:
<data file1> [<data file2>] : files with data in column-wise format 
-labels=[t,][-,]column1label[,column2label[,...]], with meaning:
  t            : abcissa (can handle dates in common formats)
  -            : ignore this column
  columnXlabel : label to give to the column in this data

Optional arguments  :
display             : shows the plot (after writing the output file)
interactive         : do not produce the output file but show it in x11
-title=...          : set the title explicitly
-out=...            : name of plot file, defaults to first data file (.$(extension $TERMINAL) extension added automaticall, if needed)
-outdir=...         : save plot file to this dir (can also be specified in -out= but this option is used in containers to ensure the file is saved to a mounted dir; overrides the path of the file specified in -out=)
-filelabels=...     : label the data in the file(s) according to this comma-separated list
quiet               : limit the user feedback
force               : delete plot file (if existing), by default no replotting is done
-xticks=...         : use special formating in the x-axis ticks: dates, float, integer, scientific (defaults to $XTICKS)
-date-format=...    : speficy the format of the dates in the data file(s) (defaults to $XDATA_FORMAT)
-date-plot=...      : speficy the format of the dates in the x-axis (defaults to $PLOT_DATE_FORMAT)
logy                : use log10 scale in the y-axis
logx                : use log10 scale in the x-axis
-start=...          : plot only from this line onwards
-len=...            : plot only this number of lines
-point-size=...     : marker size (defaults to $POINTSIZE)
dyn-point-size      : increase marker size for each additional line
-max-point-size=... : maximum size of markers when dyn-point-size (defaults to $MAX_POINTSIZE)
-font=...           : font type and size (defaults to $FONT)
-xlabel=...         : define x-axis label (defaults to none)
-ylabel=...         : define y-axis label (defaults to none)
demean              : remove the mean of all columns before plotting
-terminal=...       : set the gnuplot terminal type (defaults to $TERMINAL)
-size=...           : set the terminal size (defaults to $SIZE)
-yrange=ymin:ymax   : sets the limit of the y-axis range (defaults set whatever is set by gnuplot)
"

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
for i in "$@"
do
  case $i in 
  -labels=*)      LABELS=${i/-labels=}; LABELS=(${LABELS//,/ }) ;;
  display)        DISPLAY_FLAG=true    ;;
  interactive)    INTERACTIVE=true     ;;
  -title=*)       TITLE=${i/-title=}   ;;
  -out=*)         OUT=${i/-out=}       ;;
  -outdir=*)      OUTDIR=${i/-outdir=} ;;
  -filelabels=*)  FILE_LABELS=${i/-filelabels=}; FILE_LABELS=(${FILE_LABELS//,/ }) ;;
  quiet)          QUIET=true           ;;
  debug)          DEBUG=true           ;;
  force)          FORCE=true           ;;
  -xticks=*)      XTICKS=${i/-xticks=} ;;
  -date-format=*) XDATA_FORMAT=${i/-date-format=} ;;
  -date-plot=*)   PLOT_DATE_FORMAT=${i/-date-plot=} ;;
  logy)           LOGY=true            ;;
  logx)           LOGX=true            ;;
  -start=*)       START=${i/-start=}   ;;
  -len=*)         LEN=${i/-len=}       ;;
  -point-size=*)  POINTSIZE=${i/-point-size=} ;;
  -max-point-size=*) MAX_POINTSIZE=${i/-max-point-size=} ;;
  dyn-point-size) DYNPS=true           ;;
  -font=*)        FONT=${i/-font=}     ;;
  -xlabel=*)      XLABEL=${i/-xlabel=} ;;
  -ylabel=*)      YLABEL=${i/-ylabel=} ;;
  demean)         DEMEAN=true          ;;
  -terminal=*)    TERMINAL=${i/-terminal=} ;;
  -size=*)        SIZE=${i/-size=}     ;;
  -yrange=*)
    YRANGE=${i/-yrange=}
    if [[ "${YRANGE/:}" == "$YRANGE" ]]
    then
      echo "ERROR: input -yrange=... must contain the character ':' separating the min and max values of the y-axis range."
      exit 3
    fi
  ;;
  -h|help)        echo "$HELPSTR"; exit 0;;
  *)
    if [ -e $i ]
    then
      FILE_LIST+=($i)
    else
      echo "WARNING: ignoring argument '$i'"
    fi
  ;;
  esac
done

if [ "${LABELS:-x}" == "x" ]
then
  echo "ERROR: need -labels=* argument"
  echo "$HELPSTR"
  exit 3
fi

if [ ${#FILE_LIST[@]} -lt 1 ]
then
  echo "ERROR: need valid file name(s) as argument(s)"
  echo "$HELPSTR"
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
  [ -z "$START" ] && START=1
  for ((f=0;f<${#FILE_LIST[@]};f++))
  do
    $DEBUG && echo "---- ${FILE_LIST[f]}"
    FILE_LEN=$(cat ${FILE_LIST[f]} | wc -l)
    $DEBUG && echo "wc1 : $FILE_LEN"
    LEN=$(( FILE_LEN - START +1 ))
    $DEBUG && echo "len : $FILE_LEN"
    #get section from original file and put it in temp file
    TMPFILE=/tmp/$(basename $BASH_SOURCE).$RANDOM.$RANDOM
    middle $START $LEN ${FILE_LIST[f]} > $TMPFILE
    $DEBUG && echo "wc1 : $(cat $TMPFILE | wc -l)"
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

if ! $QUIET
then
  echo "Plotting the following files:"
  printf '%s\n' "${FILE_LIST[@]}"
  echo "labels      : ${LABELS[@]}"
  echo "display     : $DISPLAY_FLAG"
  echo "interactive : $INTERACTIVE"
  echo "title       : $TITLE"
  echo "out         : $OUT"
  echo "out dir     : $OUTDIR"
  echo "extension   : $EXT"
  echo "file labels : ${FILE_LABELS[@]}"
  echo "xticks      : $XTICKS"
  echo "date-format : $XDATA_FORMAT"
  echo "date-plot   : $PLOT_DATE_FORMAT"
  echo "logy        : $LOGY"
  echo "logx        : $LOGX"
  echo "font        : $FONT"
  echo "xlable      : $XLABEL"
  echo "ylable      : $YLABEL"
  echo "demean      : $DEMEAN"
  echo "terminal    : $TERMINAL"
  echo "size        : $SIZE"
  echo "yrange      : $YRANGE"
fi

#determine xdata column
XDATA=
COL=0
NR_COL=0
for i in ${LABELS[@]}
do
  COL=$((COL+1))
  case $i in
  "t")
    XDATA=$COL
    $QUIET || echo "x-data  is  in   column $COL"
  ;;
  "-")
    $DEBUG && echo "ignoring data in column $COL"
  ;;
  *)
    NR_COL=$((NR_COL+1))
    $QUIET || echo "plotting data in column $COL"
  ;;
  esac
done

#sanity
if [ -z "$XDATA" ]
then
  echo "ERROR: need one entry in the comma-separated list of columns in -labels=... to be 't'"
  exit 3
fi

#init gnuplot formatting commands
FMT_CMD=()

#enfore logx/y if requested
$LOGY && FMT_CMD+=(
  "set logscale y 10"
  "set format y \"%5.0e\""
)
$LOGX && FMT_CMD+=(
  "set logscale x 10"
)

#by default, expect x data to be numeric values
XDATA_CMD="(\$$XDATA)"
#enforce date format if requested
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

#user feedback
$DEBUG && echo -e "format  cmd :\n$(printf "%s\n" "${FMT_CMD[@]}")"

#init gnuplot plot command
PLOT_ARGS=()
#file column index
COL=0
#plot line index (used for consistent coloring)
c=0
for i in ${LABELS[@]}
do
  COL=$((COL+1))
  case $i in
  "t"|"-") 
    #do nothing
  ;;
  err)
    #reset file-wise color if there's only one data column
    [ $NR_COL -eq 1 ] && c=1
    cp=$((COL-1))
    for ((f=0;f<${#FILE_LIST[@]};f++))
    do
      #OFFSET and LEGEND were defined in previous iteration
      PLOT_ARGS+=("'${FILE_LIST[f]}' using $XDATA_CMD:(\$$cp - $OFFSET - \$$COL/2) with lp  ps 0 lw 1 lc $c title '${LEGEND/ ?$OFFSET} - sigma'")
      PLOT_ARGS+=("'${FILE_LIST[f]}' using $XDATA_CMD:(\$$cp - $OFFSET + \$$COL/2) with lp  ps 0 lw 1 lc $c title '${LEGEND/ ?$OFFSET} + sigma'")
      #increment file-wise color if there's only one column
      [ $NR_COL -eq 1 ] && c=$((c+1))
    done
  ;;
  *)
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
      PLOT_ARGS+=("'${FILE_LIST[f]}' using $XDATA_CMD:(\$$COL - $OFFSET) title '$LEGEND' with lp pt $((f+1)) ps $PS lw 2 lc $c")
      #increment file-wise color if there's only one column
      [ $NR_COL -eq 1 ] && c=$((c+1))
    done
  ;;
  esac
done
PLOT_CMD="plot $(printf '%s,' "${PLOT_ARGS[@]}");"

#user feedback
$DEBUG && echo "gnuplot cmd : $PLOT_CMD"

POST_FMT_CMD=()
if [ ! -z "$YRANGE" ]
then
  POST_FMT_CMD+=(
    "set yrange [$YRANGE];"
    "replot"
  )
fi

#user feedback
$DEBUG && echo -e "post fmt cmd:\n$(printf "%s\n" "${POST_FMT_CMD[@]}")"



if $INTERACTIVE
then
# https://superuser.com/questions/1096831/start-an-interactive-session-in-gnuplot-and-execute-some-commands-when-it-opens
prmpt () { (echo -n "gnuplot> " >&2) }
gnuplotInPipe () {
  echo "
set terminal x11 size $SIZE font \"$FONT\"
set autoscale
set xtic auto
set ytic auto
set grid
set title \"$TITLE\"
set xlabel \"$XLABEL\"
set ylabel \"$YLABEL\"
set mouse mouseformat \"%f,%g\"
$(printf '%s\n' "${FMT_CMD[@]}")
$PLOT_CMD
$(printf '%s\n' "${POST_FMT_CMD[@]}")"
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
set autoscale
set xtic auto
set ytic auto
set grid
set title "$TITLE"
set xlabel "$XLABEL"
set ylabel "$YLABEL"
$(printf '%s\n' "${FMT_CMD[@]}")
$PLOT_CMD
$(printf '%s\n' "${POST_FMT_CMD[@]}")
%

$DISPLAY_FLAG && display "$OUT" || echo "plotted $OUT"

fi

#cleanup
if [ ! -z "$START" ] || [ ! -z "$LEN" ] 
then
  rm -f /tmp/$(basename $BASH_SOURCE)*
fi