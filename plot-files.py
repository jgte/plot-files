#!/usr/bin/env python3

import os
import time
import sys
import collections
import argparse

for d in [\
  os.path.expanduser(os.path.join('~','utils','plot-l1b')),\
  os.path.expanduser(os.path.join('~','cloud','common','utils','plot-l1b'))\
  ]:
  if os.path.isdir(d):
    sys.path.insert(1,d)
import time_conversion as tc

import numpy as np
import matplotlib as mpl
import matplotlib.pyplot as plt
# import faulthandler; faulthandler.enable()
from operator import sub
from scipy.interpolate import interp1d
from scipy import signal
from datetime import datetime
from matplotlib.ticker import FormatStrFormatter
from matplotlib.ticker import LogFormatterMathtext
import re
import plotly.express as px
from htmlcreator import HTMLDocument
import pandas as pd

mpl.rcParams['agg.path.chunksize'] = 10000

def clean_cal(i):
  return i.replace(':','').replace('/','').replace(' ','T')

def split_results(results,typ):
  x=[]
  y=[]
  for data in results:
    x.append(data.get('gps_time'))
    y.append(data.get(typ))
  return x,y

def gauss_window(width,dx):
  x=np.linspace(-width/dx/2, width/dx/2, int(width/dx+1))
  sigma=width/dx/3
  y=1/np.sqrt(2*np.pi*sigma**2) * np.exp(-(x**2)/(2*sigma**2))
  y=y/np.sum(y)
  return y

# https://stackoverflow.com/questions/11686720/is-there-a-numpy-builtin-to-reject-outliers-from-a-list
def reject_outliers(x, m = 2.):
  d = np.abs(x - np.median(x))
  mdev = np.median(d)
  s = d/(mdev if mdev else 1.)
  return x[s<m]

def xstep(x,max_iter=10):
  c=0
  dx=np.diff(x)
  while c<max_iter and np.std(dx)!=0:
    c+=1
    dx=reject_outliers(dx)
  return np.median(dx)

#converts x,y data into a pandas series
def series_wrapper(x,y,isabs,smooth_w,ispsa):
  if isabs:
    y=np.abs(y)
  if smooth_w>0:
    dx=xstep(x)
    w=gauss_window(smooth_w,dx)
    if parsed.debug:
      print(f"dx         : {dx}")
      print(f"gauss width: {smooth_w}")
      # print(f"gauss coeff: {w}")
    y=np.convolve(y,w,'same')
  if ispsa:
    dx=xstep(x)
    x,y = signal.welch(y,1/dx,nperseg=int(16*5000/xstep(x)),detrend='linear',scaling='spectrum',average='median')
    y=np.sqrt(y)
  return pd.Series(y,index=x)

#computes the mean of y, subtracts it from y, appends it as string to dataname
def handle_mean(y,dataname,mean,demean):
  if demean:
    mean.append(np.mean(y))
    y=[yi-mean[-1] for yi in y]
    dataname=f"{dataname} {mean[-1]:9.3g}"
  else:
    mean.append(0)
  if parsed.debug:
    print(f"mean={mean[-1]}")
  return y,dataname,mean

if __name__ == '__main__':
  # argument parsing
  parser = argparse.ArgumentParser(\
    epilog="")
  parser.add_argument('-f','--files', nargs='+', type=str, required=True,
    help='files to plot')
  parser.add_argument('-b','--labels', nargs=1, type=str, required=True,
    help='columns to plot from FILES : '\
    '"t" means abcissae, "-" ignores that column (use "\-" if the first column is to be ignored), '\
    '"std" plots the confidence interval over the previous timeseries '\
    'and anything else is used to label the plot legend')
  parser.add_argument('-F','--filelabels', nargs='+', type=str, required=False, default='',\
    help='labels the FILES in the legend entries, defaults to the basename of FILES')
  parser.add_argument('-S','--start', nargs=1, type=int, required=False, default=[0], \
    help='plot only from this line onwards (not yet implemented)')
  parser.add_argument('-L','--len', nargs=1, type=int, required=False, default=[999999999999999], \
    help='plot only this number of lines (not yet implemented)')
  parser.add_argument('-o','--out', nargs=1, type=str, required=False,\
    help='filename of the resulting plot, defaults to FILES[.gGAUSS][.diff][.log][.psa].png; '\
    '"interactive" only shows the plot')
  parser.add_argument('-D','--debug', required=False, action='store_true', \
    help='show debug info')
  parser.add_argument('-d','--diff', required=False, action='store_true', \
    help='plot the difference between the first two time series (all remaining time series are discarded)')
  parser.add_argument('-H','--height', nargs=1, type=float, required=False, default=[6], \
    help='figure height in inches')
  parser.add_argument('-W','--width', nargs=1, type=float, required=False, default=[18], \
    help='figure width in inches')
  parser.add_argument('-l','--logy', required=False, action='store_true', \
    help='use logarithmic y-axis and plot absolute values')
  parser.add_argument('--logx', required=False, action='store_true', \
    help='use logarithmic x-axis')
  parser.add_argument('-T','--title', nargs=1, type=str, required=False, default='', \
    help='add this string as plot title')
  parser.add_argument('-g','--gauss', nargs=1, type=float, required=False, default=[0], \
    help='3-sigma width of the Gaussian smoothing window (same x-units as the t-column)')
  parser.add_argument('-p','--psa', required=False, action='store_true', \
    help='plot power spectrum amplitude with scipy.signal.welch')
  parser.add_argument('-s','--start-x', nargs=1, type=float, required=False, default=[-999999999999999.0], \
    help='initial x value (same x-units as the t-column)')
  parser.add_argument('-e','--end-x', nargs=1, type=float, required=False, default=[999999999999999.0], \
    help='final x value (same x-units as the t-column)')
  parser.add_argument('-w','--widen', nargs=1, type=float, required=False, default=[0], \
    help='add these many units of x-data to the start and end of the plot (only relevant when -s and/or -e are present)')
  parser.add_argument('-q','--x-date-format', nargs=1, type=str, required=False, default='none', \
    help='considers the "t" column as dates (uses matplotlib.pyplot.plot_date instead of matplotlib.pyplot.plot)')
  parser.add_argument('-z','--font-size', nargs=1, type=int, required=False, default=[12], \
    help='sets the font size of the plot')
  parser.add_argument('-X','--x-label', nargs=1, type=str, required=False, default='', \
    help='sets the x-label')
  parser.add_argument('-Y','--y-label', nargs=1, type=str, required=False, default='', \
    help='sets the y-label')
  parser.add_argument('-G','--grid', required=False, action='store_true', \
    help='turn on the major tick grid')
  parser.add_argument('-K','--force', required=False, action='store_true', \
    help='force replotting even if plot file is already available')
  parser.add_argument('-t','--timing', required=False, action='store_true', \
    help='show timing information')
  parser.add_argument('--get-supported-filetypes', required=False, action='store_true', \
    help='show supported file types and exit')
  parser.add_argument('--html', required=False, action='store_true', \
    help='plot the data as an interactive html file, using plotly (https://plotly.com/graphing-libraries/)')
  parser.add_argument('--demean', required=False, action='store_true', \
    help='remove the mean from each time series before plotting and show the mean value in the legend entry')
  parser.add_argument('--out-name', required=False, action='store_true', \
    help='show the automatic name of the resulting plot and exit (nothing is plotted)')


  #TODO: fix this
  # parser.add_argument('-n','--y-tick-fmt', nargs=1, type=str, required=False, default='{:.2f}', \
  #   help='format of the tick labels for the y-axis')

  parsed = parser.parse_args()

  #setup timing infrastructure
  if parsed.timing:
    start_time=time.time()
  def show_timing(str):
    if parsed.timing:
      print("Timinig : {str} : {sec} seconds".format(str=str,sec=(time.time() - start_time)))

  #handle incompatible arguments
  demean=parsed.demean
  if demean and parsed.psa:
    print("WARNING: --demean and --psa are incompatible, ignoring --demean")
    demean=False

  #NOTICE: this is here to make it possible to see which file types are supported in this system;
  if parsed.get_supported_filetypes:
    print(list(plt.gcf().canvas.get_supported_filetypes().keys()))
    show_timing('retrieved supported file types')
    sys.exit()
  #NOTICE: run this script with '--get-supported-filetypes -t -f 1 -b 1' to what what file types are supported and change this variable as needed
  #NOTICE: plt.gcf().canvas.get_supported_filetypes().keys() is not evaluated every time this script is run because it is very slow in some systems
  get_supported_filetypes=['eps', 'jpg', 'jpeg', 'pdf', 'pgf', 'png', 'ps', 'raw', 'rgba', 'svg', 'svgz', 'tif', 'tiff']


  #default file labels
  filelabels=[]
  for f in parsed.files:
    filelabels.append(os.path.basename(f))
  if len(parsed.filelabels)>0:
    filelabels=parsed.filelabels
  show_timing('built filelabels')

  #build plot filename
  try:
    plotfilename=parsed.out[0]
  except TypeError:
    plotfilename=''
    for f in parsed.files:
      plotfilename+=os.path.basename(f)+'.'
    if parsed.gauss[0]>0: plotfilename+='g'+str(int(parsed.gauss[0]))+'.'
    if parsed.diff:       plotfilename+='diff.'
    if parsed.logx:       plotfilename+='logx.'
    if parsed.logy:       plotfilename+='logy.'
    if parsed.psa:        plotfilename+='psa.'
    if demean:            plotfilename+='demean.'
  if parsed.debug: print(f"plotfilename.1={plotfilename}")

  extension=os.path.splitext(plotfilename)[-1]
  if extension=='.':
    plotfilename=plotfilename[0:-1]
    extension=''
  if not extension:
    if parsed.html:
      plotfilename+='.html'
    else:
      plotfilename+='.png'
      if not os.path.splitext(plotfilename)[-1][1:] in get_supported_filetypes:
        print(f"WARNING: cannot handle extension {os.path.splitext(plotfilename)[-1]}, appending '.png'.")
        plotfilename+='.png'
  if parsed.debug: print(f"plotfilename.2={plotfilename}")

  show_timing('built plotfilename')

  if parsed.out_name:
    print(plotfilename)
    exit()

  labels=[i.replace('\\-','-') for i in parsed.labels[0].split(',')]
  show_timing('built labels')

  if parsed.debug:
    print("files:     :")
    print('\n'.join(parsed.files))
    print(f"labels:    : {parsed.labels[0]}")
    print(f"labels:    : {labels}")
    print(f"filelabels : {filelabels}")
    print(f"start      : {parsed.start}")
    print(f"len        : {parsed.len}")
    print(f"out        : {plotfilename}")
    print(f"diff       : {parsed.diff}")
    print(f"height     : {parsed.height[0]}")
    print(f"width      : {parsed.width[0]}")
    print(f"logy       : {parsed.logy}")
    print(f"title      : {parsed.title}")
    print(f"gauss      : {parsed.gauss}")
    print(f"psa        : {parsed.psa}")
    print(f"start-x    : {parsed.start_x}")
    print(f"stop-x     : {parsed.end_x}")
    print(f"widen      : {parsed.widen}")
    print(f"font-size  : {parsed.font_size}")
    print(f"x-label    : {parsed.x_label}")
    print(f"y-label    : {parsed.y_label}")
    print(f"grid       : {parsed.grid}")
    print(f"force      : {parsed.force}")
    print(f"timing     : {parsed.timing}")
    print(f"html       : {parsed.html}")
    print(f"demean     : {parsed.demean}")
    # print(f"y-tick-fmt : {parsed.y_tick_fmt}")

  if os.path.isfile(plotfilename) and not parsed.force:
    print("plot "+plotfilename+" already available, skipping...")
    sys.exit()

  if not parsed.html: plt.rcParams.update({'font.size': parsed.font_size[0]})

  if parsed.psa:
    if not parsed.x_label: parsed.x_label[0]='Hz'

  dcols=()
  tcol=-1
  stdcols=()
  for i,c in enumerate(labels):
    if c=='-' or c=='_':
      continue
    elif c=='t':
      tcol=i
    else:
      dcols+=(i,)
    if c=='std':
      if i<=1: raise Exception(f"If 'std' is given in --labels, it cannot be relative to the first column.")
      stdcols+=(i,)

  if parsed.debug:
    print(f"tcol       : {tcol}")
    print(f"dcols      : {dcols}")
    print(f"stdcols    : {stdcols}")
  assert(tcol>=0),"Need one of the label entries to be 't'."
  show_timing('built column info')

  isplotted=False
  isdone=False
  rx=[]
  ry=[]
  ri=0
  ci=0
  clr={}
  plot_data={}
  plot_fill={}
  mean=[]
  for fi,fn in enumerate(parsed.files):
    if isdone:
      continue
    with open(fn, 'r') as f:
      d = f.read().splitlines()
    for di in dcols:
      if isdone:
        continue
      x=[]
      y=[]
      if di in stdcols:
        if len(parsed.files)==1:
          dataname=labels[di-1]
        else:
          dataname=filelabels[fi]+' '+labels[di-1]
      else:
        if len(parsed.files)==1:
          dataname=labels[di]
        else:
          dataname=filelabels[fi]+' '+labels[di]
      #loop over the data
      for l in d:
        dl=re.split('[\t, ]+',l)
        # if parsed.debug:
        #   print(f"dl   : {dl}")
        if parsed.x_date_format == 'none':
          try:
            t=float(dl[tcol])
          except  ValueError:
            continue
        else:
          try:
            t=datetime.strptime(dl[tcol],parsed.x_date_format[0])
          except  ValueError:
            continue
        if parsed.x_date_format != 'none' or (\
          parsed.start_x[0]-parsed.widen[0] <= t and \
            parsed.end_x[0]+parsed.widen[0] >= t \
        ):
          x.append(t)
          y.append(float(dl[di]))
      if parsed.debug:
        print(f"x={x[0:3]}...{x[-3:]}")
        print(f"y={y[0:3]}...{y[-3:]}")
      if not di in stdcols:
        #compute mean if requested (branching inside this function)
        y,dataname,mean=handle_mean(y,dataname,mean,demean)
      #save data
      rx.append(x)
      ry.append(y)
      if parsed.debug:
        print(f"ri={ri}")
        print(f"rx[{dataname}]={rx[ri][0:3]}...{rx[ri][-3:]}")
        print(f"ry[{dataname}]={ry[ri][0:3]}...{ry[ri][-3:]}")

      #branch on type of data to plot
      if di in stdcols:
        if parsed.html:
          print("NOTICE: 'std' columns not yet implemented for html plots")
        else:
          dataname=dataname+"_std"
          clr[dataname]=f"C{ci}"
          if parsed.debug:
            print(f"clr[{dataname}]={clr[dataname]}")
          #save confidence interval
          plot_data[dataname]=[
            pd.Series(np.array(ry[ri-1])-2*np.array(ry[ri]),index=rx[ri]),
            pd.Series(np.array(ry[ri-1])+2*np.array(ry[ri]),index=rx[ri])
          ]
      else:
        #save line color index
        ci+=1
        clr[dataname]=f"C{ci}"
        if parsed.debug:
            print(f"clr[{dataname}]={clr[dataname]}")
        #get plot data
        plot_data[dataname]=series_wrapper(rx[ri],ry[ri],parsed.logy,parsed.gauss[0],parsed.psa)

      if parsed.diff and ri==1:
        #set datame
        dataname="diff"
        # #get common time domain
        # xc=np.unique(np.concatenate((rx[0],rx[1])))
        #get intersection time domain
        xc=sorted(list(set(rx[0]) & set(rx[1])))
        #get interpolants for both time series
        ry0=interp1d(np.array(rx[0]),np.array(ry[0]))
        ry1=interp1d(np.array(rx[1]),np.array(ry[1]))
        #computing residuals between both interpolated time domains
        res=ry0(xc)+mean[0]-ry1(xc)-mean[1]
        if parsed.debug:
          print(f"res[{dataname}]={res[0:3]}...{res[-3:]}")
        #compute mean if requested
        if demean:
          res,dataname,mean=handle_mean(res,dataname,mean,demean)
          if parsed.debug:
            print(f"res[{dataname}]={res[0:3]}...{res[-3:]}")
        #save line color index
        ci+=1
        clr[dataname]=f"C{ci}"
        if parsed.debug:
          print(f"clr[{dataname}]={clr[dataname]}")
        #save data
        plot_data[dataname]=series_wrapper(xc,res,parsed.logy,parsed.gauss[0],parsed.psa)
        # plot_wrapper(xc,res,'diff',
        #   parsed.logy,parsed.gauss[0],parsed.psa,
        #   "C"+str(ci),parsed.x_date_format!="none")
        if parsed.debug:
          print(f"rx[ diff ]={ xc[0:3]}...{ xc[-3:]}")
          print(f"ry[ diff ]={res[0:3]}...{res[-3:]}")
        #ignore remaining time series
        isdone=True

      ri+=1
      isplotted=True
    show_timing('gathered data from {f}'.format(f=fn))

  if isplotted:
    if parsed.html:
      # Create new document with default CSS style
      document = HTMLDocument()
      # Set document title
      document.set_title(parsed.title[0])
      # gather plot data
      pdat={}
      for dataname in plot_data.keys():
        show_timing(f"start plotting {dataname}")
        if dataname[-4:]=="_std":
          print("unfinished")
        else:
          # aggregate data into a data frame
          pdat.update({dataname: plot_data[dataname]})
      fig=px.line(
        pd.DataFrame(pdat),
      )
      fig.update_layout(
        title={'text': parsed.title[0], 'x': 0.5, 'xanchor': 'center'},
        xaxis={'title': parsed.x_label[0]},
        yaxis={'title': parsed.y_label[0]},
        height=parsed.height[0]*96,
        width =parsed.width[ 0]*96,
        legend={'title': None},
      )
      document.add_plotly_figure(fig)
      # Write to file
      document.write(plotfilename)
      show_timing(f"plot saved to {plotfilename}")
      if parsed.debug:
        print("------------")
    else:
      fig=plt.figure()
      for dataname in plot_data.keys():
        show_timing(f"start plotting {dataname}")
        if dataname[-4:]=="_std":
          plt.fill_between(
            plot_data[dataname][0].index,
            plot_data[dataname][0],
            plot_data[dataname][1],
            color=clr[dataname],
            alpha=.3
          )
        else:
          plot_data[dataname].plot(label=dataname,color=clr[dataname])

      fig.set_size_inches(parsed.width[0],parsed.height[0])
      #TODO: fix this
      # plt.gca().yaxis.set_major_formatter(plt.FuncFormatter(parsed.y_tick_fmt[0].format))
      # fmt=LogFormatterMathtext(labelOnlyBase=True)
      # plt.gca().yaxis.set_major_formatter(fmt)

      if parsed.grid:    plt.grid()
      if parsed.y_label: plt.ylabel(parsed.y_label[0])
      else:
        if parsed.x_label:    plt.xlabel(parsed.x_label[0])
        # plt.xlabel('time (from '+'{}'.format(rx[0][0])+' to '+'{}'.format(rx[0][-1])+')')
        # plt.xlabel('time')
      if parsed.logx:         plt.xscale('log')
      if parsed.logy:         plt.yscale('log')
      if len(parsed.title)>0: plt.title(parsed.title[0])
      plt.legend()
      if plotfilename=='interactive':
        plt.show()
        show_timing('plot shown')
      else:
        print(plotfilename)
        plt.savefig(plotfilename,bbox_inches='tight')
        show_timing(f"plot saved to {plotfilename}")
        if parsed.debug:
          print("------------")
