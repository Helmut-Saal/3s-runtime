# 3s-runtime
Startscript to run a virtual PLC on a Edge Device

Usage:
1. Copy or download the script to the "home" folder.
```
 wget https://github.com/Helmut-Saal/3s-runtime/blob/main/DockerRuntimeStart.sh

```
2. Change rights: chmod 777 DockerRuntimeStart.sh
4. Start PLC Runtime:
```
 ./DockerRuntimeStart.sh -n X1 -a 192.168.2.240/24 -H SPS -i codesyscontrol_linux:4.7.0.0
```
