#!/bin/bash

# Installing dependencies.
echo 'Updating packages and installing dependencies'
apt-get update
apt-get install curl vim screen supervisor netcat-traditional -y
service supervisor restart

# Add a new user for all Minecraft stuff.
echo 'Setting up new user and area for Cuberite'
password=$(head -c 9 < /dev/urandom | base64)
useradd -m minecraft -s /bin/bash
echo "minecraft:$password" | chpasswd
usermod -d /home/minecraft -m minecraft

# Download the intial version of Cuberite.
echo 'Installing Cuberite'
su minecraft -c 'mkdir /tmp/Server'
su minecraft -c 'cd /tmp/Server; curl -s https://raw.githubusercontent.com/cuberite/cuberite/master/easyinstall.sh | sh'
su minecraft -c 'mv /tmp/Server/* /home/minecraft'
rmdir /tmp/Server

# Set up WebAdmin.
cd /home/minecraft
su minecraft -c 'echo stop | ./Cuberite'
su minecraft -c "sed -i -e 's/; \[User:admin\]/[User:admin]/' -e 's/; Password=admin/Password=$password/' webadmin.ini"

# Set up automatic slots.
#  There is 1 slot per 64 megabytes of ram allocated to the server.
slots=$[ $(grep MemTotal /proc/meminfo | awk '{print $2}') / 65536 ]
sed -i "s/MaxPlayers=100/MaxPlayers=$slots/" settings.ini

# Setting up the supervisor.
cat > /home/minecraft/startcuberite.sh <<EOF
#!/bin/sh

cd /home/minecraft
./Cuberite
EOF
chown minecraft /home/minecraft/startcuberite.sh
su minecraft -c 'chmod +x /home/minecraft/startcuberite.sh'

cat > /etc/supervisor/conf.d/cuberite.conf <<EOF
[program:cuberite]
command=/home/minecraft/startcuberite.sh
user=minecraft
autostart=true
autorestart=true
stderr_logfile=/var/log/cuberite.log
stdout_logfile=/var/log/cuberite.log
EOF
supervisorctl reread
supervisorctl update


# Create temporary webpage.
externip=$(dig +short myip.opendns.com @resolver1.opendns.com)

mkdir /tmp/cuberite-web
cd /tmp/cuberite-web/

cat >info.html <<EOF
<html>
<head><title>Cuberite Information</title></head>
<body>
<h1>Cuberite Information</h1>
<p>
You can log in to the webadmin at <a target="_blank" href="http://$externip:8080">http://$externip:8080</a> with username admin and password $password. You can also log in to the server via SSH with username minecraft and password $password although it is recommended you set up SSH keys.
</p>
<p><b>
This page will self-destruct when you leave it, so please note down this information!
</b></p>
</body>
</html>
EOF

