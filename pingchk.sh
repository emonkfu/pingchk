#!/bin/sh
#
# pingchk
#
# Program checks ping stats on several internet sites.
#
# This program was written to catch simple network problems.  Other programs
# do the same thing, and are usually faster.  This did exactly what was needed.
#
# Unless -rc= directory option is used, program uses config file (.rc) from
#   current directory (if it exists), then defaults to user's home directory.
# This program will use a .rc file that is .[program name].rc, so if the
#   program changes names, the .rc files will too.
# Symbolic links to the program work good for creating different configuration
#   files without having to create multiple directories to read .rc files from.
#
# Author:       Jason Woods <emonkia@gmail.com>
# Copyright:    Released into the Public Domain
# Last mod:     2010-05-06
# Version:      2.21
#
# This program may be used by anyone for any purpose as long as original
#   work credit is given to the author.

# /* start internal functions */

# function to show a function had a call error
func_callerror() {
  printf "%s\n" "" "Incorrect call to function $1 - no argument(s) sent." \
    "Usage: $*" ""
}

# function to find the program name
get_basename() {
  PROG_name="`basename ${0}`"
}

# function to find the program directory
get_dirname() {
  PROG_path="`dirname ${0}`"
}

# function to change UPPER case to lower case from input
to_lower() {
   tr [:upper:] [:lower:]
}

# function to find program info (version, update date, author, copyright)
get_proginfo() {
  PROG_vers="`cat \"$0\"|sed -n '/^# Version:/p'|sed 's/ //g'|cut -f2- -d:`"
  PROG_lupd="`cat \"$0\"|sed -n '/^# Last mod:/p'|sed 's/ //g'|cut -f2- -d:`"
  PROG_auth="`cat \"$0\"|sed -n '/^# Author:/p'|cut -c17-`"
  PROG_cpyr="`cat \"$0\"|sed -n '/^# Copyright:/p'|cut -c17-`"
}

show_version() {
  $PROG_echo "$PROG_name v$PROG_vers, $PROG_lupd"
}

show_help() {
  show_version
  printf "%s\n" \
  "" \
  "$PROG_name is a useful shell utility to check online status of servers." \
  "" \
  "usage:       $PROG_name [-rc=dir] [option]" \
  " -rc=[dir]   directory of where to find .rc file (must be first argument)" \
  "               (not required, this is for using a non-default .rc file)" \
  "options:     program action:" \
  " -quiet      quiet mode logs ping checks and alerts via email" \
  " -email      same as -quiet" \
  " -emailonly  same as -quiet, but does not do mysql logging" \
  " -logonly    quiet mode only logs ping checks, no email alert" \
  " -mysqlonly  quiet mode only logs ping checks to mysql, no email alert" \
  " -rotate     rotate the log files" \
  " -current    show current consecutive failures" \
  " -setup      configure program .rc file" \
  " -writeconf  writes configuration file and exits" \
  " -help       shows this help" \
  " -version    shows program version" \
  ""
  [ -n "$PROG_auth" ] && $PROG_echo "Written by $PROG_auth"
  [ -n "$PROG_cpyr" ] && $PROG_echo "Copyright $PROG_cpyr"
  $PROG_echo
}

# function to check for a directory and create it (and all parents) if needed
chk_dir() {
  if [ -z "$1" ] ; then
    func_callerror chk_dir "<directory to check and create if needed>"
    return 100
  fi
  [ ! -d "$1" ] && mkdir -p "$1"
  if [ ! -d "$1" ] ; then
    $PROG_echo "ERROR!  Directory \"$1\" not able to be created!"
    return 1
  fi
}

# function to create working directory and then change to it
cd_workdir() {
  chk_dir "$PCHK_workdir"
  cd "$PCHK_workdir"
}

# function to read the configuration file
read_conf() {
  # check to see if conf file exists. if not, let program know to create it
  # requires FILE_conf variable to be set to config file name
  if [ -s "$FILE_conf" ] ; then
    # conf file exists and contains data.  read it into memory
    . "$FILE_conf"
    writeconf=0
  else
    writeconf=1
  fi
}

# function to create a unique temp file name
get_tmpfname() {
  # create unique file name by using program name and date string
  $PROG_echo "/tmp/$PROG_name.`date +%Y%m%d%H%M%S`-$$.tmp"
}

# function to create a unique temp file
tmpfile_create() {
  [ -z "$TMP_file" ] && TMP_file="`get_tmpfname`"
  (umask 077 ; touch "$TMP_file")
}

# function to write to temp file created with tmpfile_create
tmpfile_write() {
  cat >> "$TMP_file"
}

# function to read temp file
tmpfile_read() {
  cat "$TMP_file"
}

# function to read temp file into the environment
tmpfile_readenv() {
  . "$TMP_file"
}

# function to remove temp file created by tmpfile_create
tmpfile_delete() {
  if [ -n "$TMP_file" ] ; then
    rm -f "$TMP_file"
    unset TMP_file
  fi
}

# function to put a variable into the environment - special cases
env_insert() {
  tmpfile_create
  $PROG_echo "$NEWVAR_tmp1=\"$NEWVAR_tmp2\"" | tmpfile_write
  tmpfile_readenv
  tmpfile_delete
}

# function to get variable descriptions from script
get_vardesc() {
  cat "$PROG_path/$PROG_name" | sed -n -e '/^# PCHK_/p' | sort -f
}

# function to get variable values from environment
get_envvars() {
  set | sed -n -e '/^PCHK_/p' | sed -e '/$PCHK_/d' | quote_vars | sort -f
}

run_setup() {
  read_conf
  WC_exit=0
  while [ "$WC_exit" = "0" ]
  do
    clear
    TEXT_1="The character \"_\" represents a space."
    TEXT_2="Hit <ENTER> when done changing options."
    CW=`expr \( $COLUMNS - 2 \) / 2`
    printf "%-$CW.${CW}s  %$CW.${CW}s" "$TEXT_1" "$TEXT_2"
    unset TEXT_1 TEXT_2
    $PROG_echo
    center_text "Ping Check Configuration"
    center_text "$FILE_conf"
    $PROG_echo
    CW=`expr \( $COLUMNS - 5 \) / 2`
    printf "  %-$CW.${CW}s  %-$CW.${CW}s\n" `get_envvars | \
      sed 's/ /_/g;s/"//g;s/^PCHK_//g'`
    $PROG_echo
    center_text -n "Change which option? "
    read VAR_name
    VAR_name="PCHK_$VAR_name"
    case "$VAR_name" in
    "PCHK_")
      $PROG_echo
      center_text -n \
        "[W]rite configuration, [R]e-enter values, or [Q]uit (w/R/q)? "
      read WC_tmp
      WC_tmp="`$PROG_echo $WC_tmp | cut -c1 | to_lower`"
      case "$WC_tmp" in
      w)
        # user wants to write configuration
        WC_exit=1
        ;;
      q)
        # user wants to quit
        WC_exit=100
        ;;
      *)
        # user wants to re-enter some values (anything else was hit)
        WC_exit=0
        ;;
      esac
      ;;
    *)
      WC_tmp="`get_vardesc | grep \"$VAR_name \" | sed -n '/^# '$VAR_name'/p'`"
      if [ -z "$WC_tmp" ] ; then
        $PROG_echo "\n\"$VAR_name\" is not a valid configuration variable name."
        sleep 3
      else
        $PROG_echo "\nDescription of \"$VAR_name\":\n$WC_tmp"
        $PROG_echo "Current value of `get_envvars | grep \"$VAR_name=\" | \
          sed 's/\"//g'`."
        input_newvar "$VAR_name"
      fi
      ;;
    esac
  done
  $PROG_echo
  [ "$WC_exit" != "1" ] && exit
  # write conf file and exit
  write_conf
  exit 0
}

# function to write configuation file
write_conf() {
  # put header, notes, help, and variables into configuration file
  (
    $PROG_echo "# Created by $PROG_name v$PROG_vers - `date`\n#" \
             "\n# $FILE_conf\n#\n# variable descriptions"
    get_vardesc
    $PROG_echo "#" \
             "\n# Make sure QUOTES are around any values with SPACES in them."
    get_envvars
  ) > $FILE_conf
}

# function to find configuration file name
get_conffile() {
  # use home dir config file by default
  FILE_conf="`$PROG_echo $HOME | sed 's/\/$//'`/.$PROG_name.rc"
  # if config file exists in current directory and is readable, use it instead
  [ -r "`pwd`/.$PROG_name.rc" ] && FILE_conf="`pwd`/.$PROG_name.rc"
}

# function to keep program from running multiple times
kill2start() {
  CUR_pid=$$
  FILE_lock="`$PROG_echo $HOME | sed 's/\/$//'`/$PROG_name-`echo $FILE_conf \
    | sed 's/\//:/g'`.lock"
  if [ ! -s "$FILE_lock" ] ; then
    touch "$FILE_lock"
    echo $CUR_pid > "$FILE_lock"
    sleep 1
    if [ ! "`cat \"$FILE_lock\"`" = "$CUR_pid" ] ; then
      # program is already running, though it didn't look like it earlier
      $PROG_echo "KILL2RUN: $CUR_pid - lock file exists - not owner."
      exit 102
    fi
  else
    # program is already running
    $PROG_echo "KILL2RUN: $CUR_pid - lock file exists."
    exit 101
  fi
  sleep 1
  rm -f "$FILE_lock"
}

# function that puts quotes around ``set'' variable values
quote_vars() {
  sed -e 's/'"$'"'//g;s/"//g;s/'"'"'//g;s/'"\\\\"'//g;s/=/="/g;s/$/"/g'
}

# function to center text on a screen line
center_text() {
  # if first argument is -n, assume no line feed required
  if [ "$1" = "-n" ] ; then
    ECHO_flag="-n"
    shift
  else
    ECHO_flag=
  fi
  TEXT_s="$*"
  TEXT_c=`expr \( $COLUMNS - length "$TEXT_s" \) / 2`
  TEXT_p=
  while [ $TEXT_c -gt 0 ]
  do
    TEXT_p="$TEXT_p "
    TEXT_c=`expr $TEXT_c - 1`
  done
  $PROG_echo $ECHO_flag "${TEXT_p}$TEXT_s"
  unset TEXT_s TEXT_c TEXT_p ECHO_flag
}

# this function gets input for run_setup function
input_newvar() {
  if [ -z "$1" ] ; then
    func_callerror input_newvar "<variable name to change value of>"
    return 100
  fi
  NEWVAR_tmp1="$1"
  $PROG_echo -n "\n<ENTER> to leave the same, SPACE for a space, or" \
                 "BLANK to make value empty.\nEnter new value: "
  read NEWVAR_tmp2
  if [ -n "$NEWVAR_tmp2" ] ; then
    # special cases
    [ "`$PROG_echo $NEWVAR_tmp2 | to_lower`" = "blank" ] && NEWVAR_tmp2=""
    [ "`$PROG_echo $NEWVAR_tmp2 | to_lower`" = "space" ] && NEWVAR_tmp2=" "
    # new value given.  put it in the environment.
    env_insert
  fi
  unset NEWVAR_tmp1 NEWVAR_tmp2
}

show_configerr() {
  $PROG_echo "Program needs configured.  Configuration file:$FILE_conf"
  $PROG_echo -n "\nRun setup (y/N)? "
  read ASK_yn
  ASK_yn="`$PROG_echo $ASK_yn | cut -c1 | to_lower`"
  if [ "$ASK_yn" = "y" ] ; then
    run_setup
  else
    exit 100
  fi
}

ping_sites() {
  for CUR_SERVER in $PCHK_sites
  do
    ping_site &
  done
  # wait until all background jobs are done
  wait
}

ping_site() {
  CUR_SITE="$CUR_SERVER"
  # get current date and time in prefered format
  TMP_datetime="`date +"%Y-%m-%d"` `date +"%H:%M:%S"`"
  # ping the site
  ping_out=`$PCHK_exe_ping -c$PCHK_pingx $CUR_SITE 2>&1`
  pingstr=`$PROG_echo "$ping_out" | grep min/avg/max`
  if [ $? -gt 0 ] ; then
    PNGCHK_text="$PCHK_text_fail"
    pingstr="n/a"
    ping_loss=100
  else
    PNGCHK_text="$PCHK_text_pass"
    pingstr=`$PROG_echo $pingstr | grep min/avg/max | \
      cut -f2 -d"=" | cut -f2 -d"/"`
    ping_loss=`echo "$ping_out" | grep "packet loss" | cut -f3 -d, | \
      cut -f1 -d% | sed 's/^ *//g'`
  fi
  [ $OUT_tty = 1 ] && output_tty
  [ $OUT_file = 1 ] && output_file
  [ $OUT_mysql = 1 ] && output_mysql
  unset TMP_datetime
  [ "$PNGCHK_text" = "$PCHK_text_fail" ] && exit 1
}

output_file() {
  # log the result to file
  [ ! -s "$CUR_SITE" ] && $PROG_echo -n "0"> "$CUR_SITE"
  # check how previous failure count of this site
  PF_count="`cat \"$CUR_SITE\"`"
  if [ "$PNGCHK_text" = "$PCHK_text_fail" ] ; then
    # keep track of how many consecutive fails happen
    PF_count="`expr $PF_count + 1`"
    $PROG_echo -n "$PF_count"> "$CUR_SITE"
    # notify about failure if between low & hi threshold
    [ $PF_count -ge $PCHK_thres_low -a $PF_count -lt $PCHK_thres_hi ] && \
      $PROG_echo "$CUR_SITE-$PF_count $PCHK_text_fail"
  else
    # notify that site is up if past low threshold
    [ $PF_count -ge $PCHK_thres_low ] && \
      $PROG_echo "$CUR_SITE-$PCHK_text_pass after $PF_count $PCHK_text_fail"
    # clear failed ping counter if not zero
    [ $PF_count -gt 0 ] && $PROG_echo -n "0"> "$CUR_SITE"
  fi
  printf "$TMP_datetime\t$PNGCHK_text\t%s\t%s\t%s\n" \
    "$pingstr" "$ping_loss" "$CUR_SITE" >> "$CUR_SITE.log"
}

output_mysql() {
  # add host to mysql command if configured
  [ -n "$PCHK_mysqlsrvr" ] && PCHK_mysqlsrvr="-h $PCHK_mysqlsrvr"
  # log the result to mysql
  if [ "$PCHK_mysql" = "1" -a -n "$PCHK_mysqluser" ] ; then
    # convert '.' and '-' characters to '_' in site name
    CUR_SITE_clean="`echo $CUR_SITE | sed 's/\./_/g;s/-/_/g'`"
    [ -n "$PCHK_mysqlpass" ] && PCHK_mysqlpass="-p $PCHK_mysqlpass"
    exec_mysql > /dev/null 2>&1
  fi
}

exec_mysql () {
  "${PCHK_exe_mysql}" ${PCHK_mysqlsrvr} -u ${PCHK_mysqluser} ${PCHK_mysqlpass} \
    -e "create database if not exists $PCHK_mysqldb"
  "${PCHK_exe_mysql}" ${PCHK_mysqlsrvr} -u ${PCHK_mysqluser} ${PCHK_mysqlpass} \
    $PCHK_mysqldb -e "create table if not exists 
    $CUR_SITE_clean(datetime datetime NOT NULL,
    pingtime decimal(9,3) unsigned default NULL,
    pcktloss tinyint(3) unsigned default NULL,
    PRIMARY KEY (datetime))"
  "${PCHK_exe_mysql}" ${PCHK_mysqlsrvr} -u ${PCHK_mysqluser} ${PCHK_mysqlpass} \
    $PCHK_mysqldb -e "insert into $CUR_SITE_clean 
    values('$TMP_datetime', '$pingstr', '$ping_loss')"
}

output_tty() {
    # log the result to tty
    printf "%-5.5s %7.7s %4.4s %s\n" \
      "$PNGCHK_text" "$pingstr" "$ping_loss" "$CUR_SITE"
}

rotate_logs() {
  cd_workdir
  for CUR_SERVER in $PCHK_sites
  do
    LOGfilel="$CUR_SERVER.log"
    count="$PCHK_logfiles"
    if [ -r "$LOGfilel" -a $count -gt 0 ] ; then
      mv -f "$LOGfilel" "$LOGfilel.0"
    fi
    while [ $count -gt 0 ]
    do
      countl="`expr $count - 1`"
      [ -r "$LOGfilel.$countl" ] && mv -f "$LOGfilel.$countl" "$LOGfilel.$count"
      count="$countl"
    done
    touch $LOGfilel
  done
  exit
}

show_current() {
  printf "%6.6s %s\n" "FAILs" "Site" "-----" "----"
  for CUR_SITE in $PCHK_sites
  do
    if [ -s "$PCHK_workdir/$CUR_SITE" ] ; then
      printf "%6s" "`cat \"$PCHK_workdir/$CUR_SITE\"`"
    else
      printf "%6s" "n/a"
    fi
    $PROG_echo " $CUR_SITE"
  done
  exit
}

create_email() {
  case "`basename $PCHK_exe_mail`" in
  mail)
    # do nothing here
    :
    ;;
  *)
    $PROG_echo "To: $PCHK_mailto"
    [ -n "$PCHK_mailcc" ] && $PROG_echo "CC: $PCHK_mailcc"
    [ -n "$PCHK_mailbcc" ] && $PROG_echo "BCC: $PCHK_mailbcc"
    [ -z "$PCHK_mailfrom" ] && PCHK_mailfrom="$LOGNAME@`hostname`"
    printf "%s\n" "From: $PCHK_mailfrom" "Subject: $MAIL_subject" ""
    ;;
  esac
  $PROG_echo "Failed pings - `$PROG_echo $PCHK_mailfrom | cut -f1 -d'<'`"
  date +"%a %m/%d %H:%M"
  tmpfile_read
  $PROG_echo "**EOT**"
}

show_scrheader() {
  # screen header
  center_text "Checking ping ability to internet sites."
  center_text "Pinging sites $PCHK_pingx times and averaging the time results"\
       "(if up) ..."
  $PROG_echo
  printf "%-5.5s %7.7s %4.4s %s\n" \
    "Avail" "AvgPing" "LOSS" "Internet Site" \
    "-----" "-------" "----" "-------------"
}

# /* end internal functions */

# if COLUMNS is not defined, default to 80
[ -z "$COLUMNS" ] && COLUMNS=80

# if running bash, be sure to make PROG_echo be echo -e
if [ -n "$BASH_VERSION" ] ; then
  PROG_echo="echo -e"
else
  PROG_echo="echo"
fi

# get program name and dir
get_basename
get_dirname
# get program information
get_proginfo
# get config file name
get_conffile

# see if program was run with arg saying where to find .rc file
if [ "`$PROG_echo "$1" | cut -c1-4`" = "-rc=" ] ; then
  if [ -d "`$PROG_echo "$1" | cut -c5-`" ] ; then
    # change to directory supplied
    FILE_conf="`$PROG_echo "$1" | cut -c5- | sed 's/\/$//'`/.$PROG_name.rc"
  else
    $PROG_echo "Directory supplied for configuration file does not exist."
  fi
  shift
fi

# /* start default variable values */

# PCHK_sites     sites that should be pinged
PCHK_sites=""
# PCHK_mailto    mailbox (primary) to send errors to
PCHK_mailto="Ping Check Mailbox <\$LOGNAME@\`hostname\`>"
# PCHK_mailcc    mailbox (secondary) to send errors to (not used if blank)
PCHK_mailcc=""
# PCHK_mailbcc   blind carbon copy mailbox to send errors to (not used if blank)
PCHK_mailbcc=""
# PCHK_mailfrom  mailbox to report errors from (uses default account if blank)
PCHK_mailfrom="Ping Check Program <\$LOGNAME@\`hostname\`>"
# PCHK_pingx     amount of times to ping sites
PCHK_pingx="10"
# PCHK_thres_low threshold to start notifying about failed ping checks
PCHK_thres_low=2
# PCHK_thres_hi  threshold to stop notifying about failed ping checks
PCHK_thres_hi=4
# PCHK_workdir   working directory for program
PCHK_workdir="`$PROG_echo $HOME | sed 's/\/$//'`/pingchk-logs"
# PCHK_logfiles  number of log files to rotate
PCHK_logfiles=6
# PCHK_text_fail text for a failed ping
PCHK_text_fail=FAIL
# PCHK_text_pass text for a successful ping
PCHK_text_pass=PASS
# PCHK_mysql     log to MySQL PCHK_mysqldb database?  0=no  1=yes
PCHK_mysql=0
# PCHK_mysqlsrvr MySQL server to log pingchk to, null if localhost
PCHK_mysqlsrvr=
# PCHK_mysqluser user name to log in to MySQL database as
# PCHK_mysqluser 1 - give this user create table/insert perms for SQL DB
PCHK_mysqluser=pingchk
# PCHK_mysqlpass password to log in to MySQL database  null=not used
# PCHK_mysqlpass 1- It is suggested to create a new MySQL user that only has
# PCHK_mysqlpass 1- permissions to insert and create data for the mysqldb DB.
# PCHK_mysqlpass 2- Also only allow user to be used from localhost, then no
# PCHK_mysqlpass 2- password would be needed as user can only add, !change/!del
PCHK_mysqlpass=
# PCHK_mysqldb   MySQL database name (netstats is default)
PCHK_mysqldb="netstats"
# OS specific programs
# PCHK_exe_mail  path, filename, and flags to mail program
# PCHK_exe_ping  path and filename of ping program
# PCHK_exe_mysql path and filename of mysql program  := not available
case "`uname`" in
SCO_SV)
  OS_type_s=sco
  PCHK_exe_ping="/usr/bin/ping"
  PCHK_exe_mail="/bin/mail"
  PCHK_exe_mysql="/usr/bin/mysql"
  ;;
Linux)
  OS_type_s=linux
  PCHK_exe_ping="/bin/ping"
  PCHK_exe_mail="/usr/sbin/sendmail -t"
  PCHK_exe_mysql="/usr/bin/mysql"
  ;;
OSF1)
  OS_type_s=osf1
  PCHK_exe_ping="/usr/sbin/ping"
  PCHK_exe_mail="/usr/sbin/sendmail -t"
  PCHK_exe_mysql="/usr/bin/mysql"
  ;;
*)
  OS_type_s=unknown
  PCHK_exe_ping="ping"
  PCHK_exe_mail="mail"
  PCHK_exe_mysql="mysql"
  ;;
esac

# check to see if sendmail exists if defaulted to mail.  if so, use sendmail
[ "`basename $PCHK_exe_mail`" = "mail" -a -x /usr/sbin/sendmail ] && \
  PCHK_exe_mail="/usr/sbin/sendmail -t"

# if mail program is still ``mail'', configure mailto in a different way
[ "`basename $PCHK_exe_mail`" = "mail" ] && \
  PCHK_mailto="\$LOGNAME@\`hostname\`"

# /* end default variable values */

# if config file does not exist, create it and exit with an error
if [ ! -s $FILE_conf ] ; then
  write_conf
  show_configerr
fi

# read in configuration file
. "$FILE_conf"

# default run mode values
OUT_tty=0
OUT_email=0
OUT_file=0
OUT_mysql=0

# find out what mode program should run as
case "`$PROG_echo $1 | sed 's/-//g'`" in
rotate)
  rotate_logs
  exit 0
  ;;
current)
  show_current
  exit 0
  ;;
setup)
  run_setup
  exit 0
  ;;
writeconf)
  write_conf
  exit 0
  ;;
quiet|email)
  OUT_email=1
  OUT_file=1
  OUT_mysql=1
  ;;
emailonly)
  OUT_email=1
  OUT_file=1
  ;;
logonly)
  OUT_file=1
  OUT_mysql=1
  ;;
mysqlonly)
  OUT_mysql=1
  ;;
h|help)
  show_help
  exit 0
  ;;
v|version)
  show_version
  exit 0
  ;;
*)
  OUT_tty=1
  ;;
esac

# if PCHK_sites is not set, show error in configuration.
if [ -z "$PCHK_sites" ] ; then
  if [ $OUT_tty = 1 ] ; then
    center_text "PCHK_sites does not contain any sites to work with."
    show_configerr
  else
    exit 99
  fi
fi

# /* actual work starts here */

# make sure program isn't running more than once at a time
if [ "$OUT_email" = "1" -o "$OUT_file" = "1" -o "$OUT_mysql" = "1" ] ; then
  if [ "$OUT_tty" = "1" ] ; then
    kill2start
  else
    kill2start > /dev/null 2>&1
  fi
fi

# check to see if mysql exists if using mysql, if not, make un-executable
[ ! -x "$PCHK_exe_mysql" ] && PCHK_exe_mysql=":"

# change to working directory (create if needed)
cd_workdir

# show screen header if not running in quite mode
[ $OUT_tty = 1 ] && show_scrheader

# create temp file for output
tmpfile_create

# send the output to temp file
ping_sites | sort | tmpfile_write

# see if output is sent to screen
if [ $OUT_tty = 1 ] ; then
  # normal mode.  show output on the screen, no logging or email creation.
  tmpfile_read
fi
# see if output needs emailed
if [ $OUT_email = 1 ] ; then
  # quiet mode.  log attempts and create email if needed, no screen output.
  if [ -s "$TMP_file" -a -n "$PCHK_mailto" ] ; then
    MAIL_subject="Failed Pings"
    case "`basename $PCHK_exe_mail`" in
    mail)
      create_email 2>&1 | $PCHK_exe_mail -s "$MAIL_subject" \
        $PCHK_mailto $PCHK_mailcc $PCHK_mailbcc
      ;;
    *)
      create_email 2>&1 | $PCHK_exe_mail
      ;;
    esac
  fi
fi

# count how many sites failed, exit with that number
ERR_count="`tmpfile_read 2> /dev/null | grep -c \"$PCHK_text_fail\"`"

# make sure we cap off the top limit to error number
[ $ERR_count -gt 98 ] && ERR_count=98

# remove the temp file
tmpfile_delete

exit $ERR_count
