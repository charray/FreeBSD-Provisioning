#!/bin/sh -x

#
# Copyright (c) 2017, Kinson Chan
# All rights reserved.
# 
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are met:
#
# 1. Redistributions of source code must retain the above copyright notice, this
#    list of conditions and the following disclaimer.
# 2. Redistributions in binary form must reproduce the above copyright notice,
#    this list of conditions and the following disclaimer in the documentation
#    and/or other materials provided with the distribution.
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
# ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
# WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
# DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR
# ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
# (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
# LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
# ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
# (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
# SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
#

#
# Disable Sendmail
#
logger Disabling Sendmail
sysrc sendmail_enable="NONE"

#
# Disable Periodic Email
#
logger Disabling Periodic Emails
pfile="/etc/periodic.conf"
sysrc -f $pfile daily_output="/var/log/daily.log"
sysrc -f $pfile daily_output="/var/log/daily.log"
sysrc -f $pfile weekly_output="/var/log/weekly.log"
sysrc -f $pfile monthly_output="/var/log/monthly.log"
sysrc -f $pfile daily_status_security_output="/var/log/daily.log"
sysrc -f $pfile weekly_status_security_output="/var/log/weekly.log"
sysrc -f $pfile monthly_status_security_output="/var/log/monthly.log"
sysrc -f $pfile daily_clean_hoststat_enable="NO"
sysrc -f $pfile daily_backup_aliases_enable="NO"
sysrc -f $pfile daily_status_mailq_enable="NO"
sysrc -f $pfile daily_status_include_submit_mailq="NO"
sysrc -f $pfile daily_status_mail_rejects_enable="NO"
sysrc -f $pfile daily_queuerun_enable="NO"

#
# Disable TTYs
#
logger Disabling Virtual Terminals
sed -ibak '/ttyv2/s/on /off/; /ttyv3/s/on /off/; /ttyv4/s/on /off/; /ttyv5/s/on /off/; /ttyv6/s/on /off/; /ttyv7/s/on /off/' /etc/ttys

#
# NTP service
#
logger Configuring NTP
sysrc ntpd_enable="YES"

#
# PF service
#
logger Configuring PF
cat > /etc/pf.conf << EOF
extif="vtnet0"
tcpports="{22,80,443}"
martians="{127.0.0.0/8,192.168.0.0/16,172.16.0.0/12,
  10.0.0.0/8,169.254.0.0/16,192.0.2.0/24,
  0.0.0.0/8,240.0.0.0/4}"
table <spammers> persist
set skip on lo

block all
block drop in quick from <spammers> to any
block drop in quick on \$extif from \$martians to any
pass out quick inet proto udp from any to 255.255.255.255 port {67,68}
block drop out quick on \$extif from any to \$martians

pass out quick
pass in quick inet proto icmp from any to any
pass in quick inet proto tcp from any to any port \$tcpports keep state \
  (max-src-conn 100, max-src-conn-rate 100/1 \
   overload <spammers> flush global)
EOF
cat >> /etc/crontab << EOF
*/5 * * * * root /sbin/pfctl -t spammers -T expire 86400 > /dev/null 2>&1
EOF
sysrc pf_enable="YES"

#
# Shell environment
#
logger Configuring TCSH environment
cat > /root/.cshrc << EOF
alias h history 25
alias j jobs -l
alias la ls -aF
alias lf ls -FA
alias ll ls -lAF

umask 22

set path = (/sbin /bin /usr/sbin /usr/bin /usr/games /usr/local/sbin /usr/local/bin \$HOME/bin)

setenv EDITOR vi
setenv PAGER more
setenv BLOCKSIZE K

if (\$?prompt) then
  alias ls ls -G
  alias cp cp -i
  alias mv mv -i
  alias rm rm -i
  alias ln ln -i
  alias link link -i

   if (\$uid == 0) then
     set user = root
   endif

   set prompt="%B%n%b@%B%m%b %B%~%b%# "
   set noclobber
   set rmstar
   set autolist
   set filec
   set history = 1000
   set savehist = (1000 merge)
   set autolist = ambiguous
   set autoexpand
   set autorehash
   set mail = (/var/mail/\$USER)
   if (\$?tcsh) then
     bindkey "^W" backward-delete-word
     bindkey -k up history-search-backward
     bindkey -k down history-search-forward
   endif
endif
EOF
cp -a /root/.cshrc /usr/share/skel/dot.cshrc
chpass -s /bin/tcsh root #

# VIM environment
logger VIM environments
cat > /root/.vimrc << EOF
set nomodeline
set copyindent
set autoindent
set nowrap
set cc=80
syntax on
EOF
cp -a /root/.vimrc /usr/share/skel/dot.vimrc

#
# Refresh the pkg and install packages
#
logger Configuring Packages 
export ASSUME_ALWAYS_YES=yes
/usr/sbin/pkg bootstrap -f
/usr/local/sbin/pkg-static delete \*
/usr/local/sbin/pkg-static update
/usr/local/sbin/pkg-static upgrade
/usr/local/sbin/pkg-static install vim-lite tmux

#
# Restart the TTYs and enforce new Sysctl
#
kill -HUP 1
sysctl -f /etc/sysctl.conf

#
# Send ALARM signal to reload rc.conf, if necessary
#
if [ $RC_PID ]
then
  kill -SIGALRM $RC_PID
fi
