iptables-restore < /home/dave/dockernew.save 
export INTERFACE=`ip addr | grep 172.29 | sed 's/\s+/ /g' | cut -d' ' -f 11 | tr '\n' ' '`
docker stop $1
docker rm $1         
docker network rm freeswitch_network
docker network create -d bridge --subnet=172.29.0.0/24  \
 --opt com.docker.network.bridge.enable_icc="true" \
 --opt com.docker.network.bridge.enable_ip_masquerade="true" \
 --opt com.docker.network.bridge.host_binding_ipv4="0.0.0.0" \
 --opt com.docker.network.driver.mtu="1500" freeswitch_network

export INTERFACE=`ip addr | grep 172.29 | sed 's/\s+/ /g' | cut -d' ' -f 11 | tr '\n' ' '`

docker run -itd  \
    --cap-add=NET_ADMIN \
    --network=freeswitch_network \
    --ip=172.29.0.15 \
    --name $1 \
    -ti \
    freeswitch \
    /bin/bash

docker exec $1 ip a add 172.29.0.16/24  dev eth0

export CIP=172.29.0.15
export CINTERNAL=172.29.0.16

sysctl -w net.ipv4.ip_forward=1

iptables -A DOCKER -t nat -p udp -m udp ! -i $INTERFACE --dport 16384:32768 -j DNAT --to-destination $CIP:16384-32768
iptables -A DOCKER -t nat -p udp -m udp ! -i $INTERFACE --dport 6065 -j DNAT --to-destination $CIP:6065
iptables -A DOCKER -t nat -p udp -m udp ! -i $INTERFACE --dport 6060 -j DNAT --to-destination $CIP:6060
iptables -A DOCKER -t nat -p udp -m udp ! -i $INTERFACE --dport 5065 -j DNAT --to-destination $CINTERNAL:5065
iptables -A DOCKER -t nat -p tcp -m tcp ! -i $INTERFACE --dport 5065 -j DNAT --to-destination $CINTERNAL:5065
iptables -A DOCKER -t nat -p tcp -m tcp ! -i $INTERFACE --dport 7001 -j DNAT --to-destination $CINTERNAL:7001
iptables -A DOCKER -t nat -p udp -m udp ! -i $INTERFACE --dport 5514 -j DNAT --to-destination $CIP:5514

iptables -A DOCKER -p udp -m udp -d $CIP/32 ! -i $INTERFACE -o $INTERFACE --dport 6060 -j ACCEPT
iptables -A DOCKER -p udp -m udp -d $CIP/32 ! -i $INTERFACE -o $INTERFACE --dport 6065 -j ACCEPT
iptables -A DOCKER -p udp -m udp -d $CINTERNAL/32 ! -i $INTERFACE -o $INTERFACE --dport 5065 -j ACCEPT
iptables -A DOCKER -p tcp -m tcp -d $CINTERNAL/32 ! -i $INTERFACE -o $INTERFACE --dport 5065 -j ACCEPT
iptables -A DOCKER -p tcp -m tcp -d $CINTERNAL/32 ! -i $INTERFACE -o $INTERFACE --dport 7001 -j ACCEPT
iptables -A DOCKER -p udp -m udp -d $CIP/32 ! -i $INTERFACE -o $INTERFACE --dport 5514 -j ACCEPT
iptables -A DOCKER -p udp -m udp -d $CIP/32 ! -i $INTERFACE -o $INTERFACE --dport 16384:32768 -j ACCEPT

iptables -A POSTROUTING -t nat -p udp -m udp -s $CIP/32 -d $CIP/32 --dport 16384:32768 -j MASQUERADE
iptables -A POSTROUTING -t nat -p udp -m udp -s $CIP/32 -d $CIP/32 --dport 6065 -j MASQUERADE
iptables -A POSTROUTING -t nat -p udp -m udp -s $CIP/32 -d $CIP/32 --dport 6060 -j MASQUERADE
iptables -A POSTROUTING -t nat -p udp -m udp -s $CINTERNAL/32  -d $CINTERNAL/32 --dport 5065 -j MASQUERADE
iptables -A POSTROUTING -t nat -p tcp -m tcp -s $CINTERNAL/32 -d $CINTERNAL/32 --dport 5065 -j MASQUERADE
iptables -A POSTROUTING -t nat -p tcp -m tcp -s $CINTERNAL/32 -d $CINTERNAL/32 --dport 7001 -j MASQUERADE
iptables -A POSTROUTING -t nat -p udp -m udp -s $CIP/32 -d $CIP/32 --dport 5514 -j MASQUERADE

docker exec $1 /usr/local/freeswitch/bin/freeswitch -nc 
docker exec $1 /etc/init.d/syslog-ng start
docker exec -d $1 sh -c 'cd /usr/editor && cp data/config-0_0_0_0.php data/config-172_29_0_16.php && php -S 172.29.0.16:7001'
