#!/system/bin/sh
# prints "<proc> <state> <remote ip:port>" for TCP sockets owned by BYD cloud daemons (run as root on device)
for p in $(pidof mqttserv cloudmanager cloudctrlserv netd) $*; do
  n=$(cat /proc/$p/comm)
  for fd in /proc/$p/fd/*; do readlink $fd; done 2>/dev/null | sed -n 's/socket:\[\([0-9]*\)\]/\1/p' | while read ino; do
    awk -v ino=$ino -v n="$n" 'NR>1 && $10==ino {print n, $4, $3}' /proc/net/tcp /proc/net/tcp6
  done
done | while read n s r; do
  ip=${r%:*}; port=$((16#${r#*:}))
  if [ ${#ip} -eq 8 ]; then a=$((16#${ip:6:2})).$((16#${ip:4:2})).$((16#${ip:2:2})).$((16#${ip:0:2})); else a=$ip; fi
  case $s in 01) s=ESTAB;; 02) s=SYN_SENT;; 0A) s=LISTEN;; 06) s=TIME_WAIT;; 08) s=CLOSE_WAIT;; esac
  echo "$n $s $a:$port"
done
