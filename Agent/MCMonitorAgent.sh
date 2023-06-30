#!/bin/bash
#

export HOME=/home/mcmonitor/MCMonitorPerl
export AGENTHOME=${HOME}/Agent
export PERL5LIB=${AGENTHOME}/lib

perl ${AGENTHOME}/MCMonitorAgent.pl
