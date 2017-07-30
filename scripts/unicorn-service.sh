#!/bin/bash

unicorn_pid_file=log/unicorn.pid
unicorn_conf=config/unicorn.rb

# Get the pid if we can
if [ -f ${unicorn_pid_file} ]; then
    unicorn_pid=$(cat ${unicorn_pid_file})
fi

start() {
    if [ -e ${unicorn_pid} ]; then
        ~/.rvm/gems/ruby-2.3.3/bin/bundle exec unicorn -c ${unicorn_conf} -D
    fi
}

stop() {
    if ! [ -e ${unicorn_pid} ]; then
        kill -TERM ${unicorn_pid}
    fi
}

reload() {
    if ! [ -e ${unicorn_pid} ]; then
        kill -USR2 ${unicorn_pid}
    else
        start
    fi
}

restart() {
    stop
    start
}

case $1 in
    start) start ;;
    stop) stop ;;
    reload) reload ;;
    restart) restart ;;
    *) echo "Usage: ${0} start|restart|reload|stop"
esac
