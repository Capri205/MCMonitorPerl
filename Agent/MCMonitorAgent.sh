#!/bin/sh
#

export HOME=/home/mcmonitor/MCMonitorPerl
export AGENTHOME=${HOME}/Agent
export PERL5LIB=${AGENTHOME}/lib

/usr/local/bin/perl ${AGENTHOME}/MCMonitorAgent.pl
