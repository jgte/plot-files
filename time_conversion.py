#! /usr/bin/env python

#####################
# time_conversion.py
#   Time Conversions 
#   Author: nathan calderon
#   Revision: 10/12/17 - removed leapseconds.py dependency
#####################

import calendar
import time
from datetime import datetime
import math
import decimal
Decimal = decimal.Decimal
decimal.getcontext().prec=40

EPOCH_OFFSET = calendar.timegm((2000,1,1,12,0,0,0)) #seconds from 1970 -> jan 1 2000, noon

def get_leapseconds(gps_unix_raw): # takes unix time struct created from EPOCH+J2000
    filename = '/home1/00764/byab343/LEAPDAT'
    count = 1
    mjd_list = []
    leap_year_list = []
    leap_skiped = 11 # leapseconds added between 1968-1980
    leap_seconds = 0

    with open(filename, 'rb') as lines:
        for line in lines:
            data = line.split('#')
            mjd = data[0]
            date =  data[1].split(' ')[1][:-1]
            date = date.split('/')
            year = date[0]
            mon =  date[1]
            day =  date[2]
            date_str = year+mon+day
            leap_year_list.append(date_str)
            mjd_list.append(mjd)

    for year in leap_year_list:
        if gps_unix_raw.tm_year <= int(year[0:4]):
            #print '{} <= {}'.format(gps_unix_raw.tm_year, year[0:4])
            if gps_unix_raw.tm_year == int(year[0:4]):
                #print '{} == {}'.format(gps_unix_raw.tm_year, year[0:4])
                if gps_unix_raw.tm_mon >= int(year[4:5]):
                    #print '{} >= {}'.format(gps_unix_raw.tm_mon, year[4:5])
                    if gps_unix_raw.tm_mon == int(year[4:5]):
                        #print '{} == {}'.format(gps_unix_raw.tm_mon, year[4:5])
                        if gps_unix_raw.tm_mday >= int(year[5:6]):
                            #print '{} <= {}'.format(gps_unix_raw.tm_mday, year[5:6])
                            break
                    else:
                        break
                else:
                    count = count - 1
                    break
            else:
                count = count - 1
                break
        else:
            count = count + 1
    leap_seconds = count
    return leap_seconds - leap_skiped

def cal_to_gps(*arg):
    """Assumes UTC"""
    if len(arg)==1:
        return calendar.timegm((arg[0].tm_year, arg[0].tm_mon, arg[0].tm_mday, arg[0].tm_hour, arg[0].tm_min, arg[0].tm_sec)) - EPOCH_OFFSET
    elif len(arg)==6:
        return calendar.timegm((arg[0], arg[1], arg[2], arg[3], arg[4], arg[5])) - EPOCH_OFFSET
    else:
        raise RuntimeError('Expecting 1 or 6 input arguments, not '+str(len(arg)))

def gps_to_cal(gps_time_int):
    """Assumes UTC"""
    return time.gmtime(EPOCH_OFFSET+gps_time_int)

def utc_cal_to_gps(year, month, day, hour, minute, second):
    temp_time = gps_to_cal(cal_to_gps(year,month,day,hour,minute,second))
    return ((cal_to_gps(year,month,day,hour,minute,second)) + get_leapseconds(temp_time))

def gps_time_to_gps_week(gps_time_int):
    GPS_WEEK_OFFSET = -cal_to_gps(1980,1,6,0,0,0)
    return ((gps_time_int+GPS_WEEK_OFFSET)/604800,(gps_time_int+GPS_WEEK_OFFSET)%604800)

def gps_week_to_gps_time(gps_week_int, gps_week_seconds_int):
    GPS_WEEK_OFFSET = -cal_to_gps(1980,1,6,0,0,0)
    initial_time = gps_week_int*604800 + gps_week_seconds_int
    return initial_time - GPS_WEEK_OFFSET

def JD_time_to_gps(JD_float):
    JD_float = Decimal(JD_float)+Decimal(.5) #Add .5 in order to offset the GPS_time half day
    jdn = int(math.floor(JD_float))
    dec = JD_float - jdn

    #Is there a way to do this in less lines, or is it recursively dependent like this?
    L= jdn+68569
    N= 4*L/146097
    L= L-(146097*N+3)/4
    I= 4000*(L+1)/1461001
    L= L-1461*I/4+31
    J= 80*L/2447
    K= L-2447*J/80
    L= J/11
    J= J+2-12*L
    I= 100*(N-49)+I+L

    year = I
    month = J
    day = K
    hour = 0
    minute = 0
    sec = int(round(dec*86400))

    #this is gross, but works well
    temp_time = gps_to_cal(cal_to_gps(year,month,day,hour,minute,sec)) # I hate this line
    '''Old code below, this code used leapseconds.py, a now defuct module 
    cal_datetime = datetime(temp_time.tm_year, temp_time.tm_mon, temp_time.tm_mday, temp_time.tm_hour, temp_time.tm_min, temp_time.tm_sec)
    #####################*************** LEAPSECONDS USED **************###################
    count_leapseconds = (cal_datetime - leapseconds.gps_to_utc(cal_datetime)).seconds
    '''
    # with the relative date, retrieve leapseconds
    leaps = get_leapseconds(temp_time)
    # leapseconds subtracted from secs to convert to UTC    
    return cal_to_gps(year,month,day,hour,minute,sec+leaps)

def gps_time_to_JD(gps_time_int): # assumes GPS_J2000_Noon value
    
    # create a unix timestamp from gps_time_int, this is considered a relative date used to get leapseconds
    unix_gps = time.gmtime(gps_time_int+EPOCH_OFFSET)
    # with the relative date, retrieve leapseconds
    leaps = get_leapseconds(unix_gps)
    # leapseconds subtracted from gps_time_int to convert to UTC
    gps_utc = gps_time_int-leaps
    # retrieve a time struct with UTC corrected GPS time
    cur_date = time.gmtime(gps_utc+EPOCH_OFFSET)
    ''' Old code below, this code used leapseconds.py, a now defuct module
    # these lines get complicated
    datetime_date = datetime.fromtimestamp(time.mktime(gps_to_cal(gps_time_int))) #this line creates a 'datetime' object from the given gps_time
    #####################*************** LEAPSECONDS USED **************###################
    count_leapseconds = (datetime_date - leapseconds.gps_to_utc(datetime_date)).seconds # this line gets the number of leap seconds separating UTC and GPS
    cur_date = gps_to_cal(gps_time_int - count_leapseconds)
        '''
    a = math.floor((14-(cur_date.tm_mon))/12.)
    y = cur_date.tm_year + 4800 - a
    m = cur_date.tm_mon + 12*a - 3
    
    jdn = Decimal(cur_date.tm_mday+math.floor((153*m+2)/5.0)+365*y+math.floor(y/4.0)-math.floor(y/100.0)+math.floor(y/400.0)-32045)
    return jdn + Decimal((Decimal(cur_date.tm_hour-12)/Decimal(24)) + (Decimal(cur_date.tm_min)/Decimal(1440)) + (Decimal(cur_date.tm_sec)/Decimal(86400)))

