#!/bin/sh
#

### BEGIN INIT INFO
# Provides:   minecraft
# Required-Start: $local_fs $remote_fs
# Required-Stop:  $local_fs $remote_fs
# Should-Start:   $network
# Should-Stop:    $network
# Default-Start:  2 3 4 5
# Default-Stop:   0 1 6
# Short-Description:    BunGeecord
# Description:    Starts the BunGeecord server
### END INIT INFO

#SERVER='Travertine.jar'
#SERVER='Waterfall.jar'
SERVER='ForgeMod.jar'
SCREENAME="ob-traincraft"
USER='mcadmin'
HEAP_MAX=4096
HEAP_MIN=4096
HISTORY=32
HOME="/home/mcadmin/${SCREENAME}/Minecraft"
JAVA="/usr/lib/jvm/java-1.8.0-openjdk-amd64/bin/java"
INVOCATION="${JAVA} -server -Xmx${HEAP_MAX}M -Xms${HEAP_MIN}M -Djline.terminal=jline.UnsupportedTerminal -Djava.awt.headless=true -Dfml.queryResult=confirm -jar ${SERVER} -nogui"
ME=`whoami`

cd ${HOME}

as_user() {
  if [ "${ME}" = "${USER}" ] ; then
    bash -c "$1"
  else
    #su - ${USER} -c "$1"
    su - ${USER} -c "$1"
  fi
}

cmd() {
  command="$1";
  logfile="${HOME}/logs/latest.log"
  if server_running
  then
    pre_log_len=`wc -l "${HOME}/logs/latest.log" | awk '{print $1}'`
    #as_user "screen -p 0 -S ${SCREENAME} -X eval 'stuff \"${command}\"\015'"
    as_user "/usr/bin/screen -dr ${SCREENAME} -X eval 'stuff \"${command}\"\015'"
    sleep .2
    V=`wc -l ${logfile} | awk '{print $1}'`-${pre_log_len}
    #tail -n $[V] ${logfile}
    tail -4 ${logfile}
  else
    echo "${SERVER} was not running. Not able to run command."
  fi
}

server_running() {
  if ps ax | grep SCREEN | grep ${SCREENAME} | grep ${SERVER} > /dev/null
  then
    return 0
  else
    return 1
  fi
}

start() {
  if server_running
  then
    echo "${SCREENAME} is already running!"
  else
    as_user "/usr/bin/screen -h ${HISTORY} -dmS ${SCREENAME} ${INVOCATION}"
    if server_running
    then
      echo "${SCREENAME} is now running."
    else
      echo "Error! Could not start ${SCREENAME}!"
    fi
  fi
}

stop() {
  if server_running
  then
    echo "Stopping ${SCREENAME}"
    cmd stop
  else
    echo "${SCREENAME} was not running."
  fi
}

case "$1" in
  start)
    start
    ;;
  stop)
    stop
    ;;
  restart)
    stop
    sleep 5
    start
    ;;
  status)
    if server_running
    then
      echo "${SCREENAME} is running."
    else
      echo "${SCREENAME} is not running."
    fi
    ;;

  *)
  echo "Usage: $0 {start|stop|status|restart}"
  exit 1
  ;;
esac

exit 0

