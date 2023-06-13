#!/bin/bash

# This script can be used as an example on how to start your docker container for CODESYS virtual Control.

LANG=en
SUDO=$(which sudo)

# Files and folders
NETNSFOLDER=/var/run/netns/

# Parts of docker run command
RTIMAGE=""
NICCOMMAND=""
LICENSESERVERCOMMAND=""
CONTAINERNAMECOMMAND=""
HOSTNAMECOMMAND=""

usage()
{
cat <<EOF
OPTIONS := { 
  -n | --nic            map network interface (nic) to runtime container
  -a | --nicip          specify an ip address with subnet for the nic. This only takes effect with -n
  -i | --image          runtimeimage to start (Mandatory!)
  -s | --licenseserver  add license-server by IP address
  -c | --containername  set a name for the running container
  -H | --hostname       set a hostname for the running container. Under this name, the runtime is shown in the scan.
  -h | --help           display this help
}
EOF
}

# get and parse options
options=$(getopt --long "nic:,nicip:,image:,licenseserver:,containername:,hostname:,help" \
                   -o "n:,a:,i:,s:,c:,H:,h" -- "$@")

if [ $? -ne 0 ]; then
        usage
        exit 1
fi

eval set -- "$options"

while [[ $1 != -- ]]
do
  case "$1" in
    -n | --nic)
        NICTOMAP=${2}
        NICCOMMAND="-n ${NICTOMAP}"
        shift ;;
    -a | --nicip)
        NICADDRESS=${2}
        shift ;;
    -i | --image)
        RTIMAGE=${2}
        shift ;;
    -s | --licenseserver)
        LICENSESERVER=${2}
        LICENSESERVERCOMMAND="-s ${LICENSESERVER}"
        shift ;;
    -c | --containername)
        CONTAINERNAME=${2}
        CONTAINERNAMECOMMAND="--name ${CONTAINERNAME}"
        shift ;;
    -H | --hostname)
        RTHOSTNAME=${2}
        HOSTNAMECOMMAND="--hostname ${RTHOSTNAME}"
        shift ;;
    -h | --help)
        usage	
        exit 0
        ;;
    *)
        echo "[ERROR] unknown option: "${1}
        usage	
        exit 1
        ;;
    esac
    shift
done

if [ -z $RTIMAGE ] ; then
    echo "[ERROR] no runtimeimage specified"
    usage
    exit 1
fi


# cleanup old temporary container id file
rm -f ${CIDFILERT}

# run runtime
echo "[INFO] Starting runtime"

###################################################################################################################################################
# The following command starts the docker container from the docker image.
# -rm removes the container after it is stoped. (optional)
# -d starts the container detatched from the shell. (optional)
# -t allocates a pseudo-TTY. This improves the output to the terminal. (recommended)
# -v declares the mounting points from host to container.
#       The first mount in the example keeps the configuration files persistent (required)
#       The second mount is used to store the application, the bootproject, etc. (required)
#       The third and fourth mounts are needed for the use of the extension package. (optional)
# -p is used for the portmapping. If you want to use multiple containers it is important to remap the ports for every container.
#       On the second container the port mapping could look like this: -p 11741:11740/tcp -p 444:443/tcp [...] 
#       The first value is what port is seen on the outside of the container. (optional, but required, if you want to contact the runtime direclty)
# --cap-add adds capabilities to the container. (optional, but required, if you dont want to use priviledged mode)

# The parameters for the license-server as well as the parameter for the network interface can either be set with variables for the startup script
#       e.g.: docker run <docker-params> <image> -s 10.10.10.10 -n eth0
# of with the use of environment variables
#       e.g.: docker run -e LICENSESERVER=10.10.10.10 -e NICTOMAP=eth0 <remaining docker-params> <image>
###################################################################################################################################################

RUNTIMEID=$(docker run \
 --rm \
 ${CONTAINERNAMECOMMAND} \
 ${HOSTNAMECOMMAND} \
 -d \
 -t \
 -v ~/dockerMount/conf/codesyscontrol/:/conf/codesyscontrol/ \
 -v ~/dockerMount/data/codesyscontrol/:/data/codesyscontrol/ \
 -v /var/run/codesysextension/:/var/run/codesysextension/ \
 -v ~/dockerMount/extension/codesyscontrol/:/var/opt/codesysextension/ \
 -v /media:/media \
 -p 11740:11740/tcp \
 -p 443:443/tcp \
 -p 8080:8080/tcp \
 -p 4840:4840/tcp \
 --cap-add CHOWN \
 --cap-add IPC_LOCK  \
 --cap-add KILL  \
 --cap-add NET_ADMIN  \
 --cap-add NET_BIND_SERVICE \
 --cap-add NET_BROADCAST  \
 --cap-add NET_RAW  \
 --cap-add SETFCAP  \
 --cap-add SETPCAP  \
 --cap-add SYS_ADMIN \
 --cap-add SYS_MODULE  \
 --cap-add SYS_NICE \
 --cap-add SYS_PTRACE  \
 --cap-add SYS_RAWIO \
 --cap-add SYS_RESOURCE  \
 --cap-add SYS_TIME \
  ${RTIMAGE} \
  ${NICCOMMAND} ${LICENSESERVERCOMMAND})


if [ $? -ne 0 ] ; then
  echo "[ERROR] error starting runtime"
  exit 1
fi

# map nic to runtime container
if [ ! -z $NICTOMAP ] ; then
  echo "[INFO] mapping ${NICTOMAP} to containerid ${RUNTIMEID}"

  # Prepare
  $SUDO mkdir -p ${NETNSFOLDER}

  # Extract pid of container
  CONTAINERPID=$(docker inspect --format='{{ .State.Pid }}' ${RUNTIMEID})
 
  # Create a link, so we can use the tool ip
  # Note that the namespace is represented by the filename in /var/run/netns/<> 
  echo "[INFO] creating link ${NETNSFOLDER}${RUNTIMEID} to /proc/$CONTAINERPID/ns/net"
  $SUDO ln -sfT /proc/$CONTAINERPID/ns/net ${NETNSFOLDER}${RUNTIMEID}
  if [ $? -ne 0 ] ; then
    echo "[Error]: creating link failed"
    exit 1
  fi
  
  # Here is where the remapping happens. We will map the nic into the namespace of the docker container
  $SUDO ip link set ${NICTOMAP} netns ${RUNTIMEID}
  if [ $? -ne 0 ] ; then
    echo "[Error] setting the namespace of ${NICTOMAP} failed"
    exit 1
  fi 
  # Now we have to bring the nic up
  $SUDO ip netns exec ${RUNTIMEID} ip link set ${NICTOMAP} up
  if [ $? -ne 0 ] ; then
    echo "[Error] set ${NICTOMAP} up failed"
    exit 1
  fi 

  # Set promisc mode
  $SUDO ip netns exec ${RUNTIMEID} ip link set ${NICTOMAP} promisc on
  if [ $? -ne 0 ] ; then
    echo "[Error] set pomisc of ${NICTOMAP} failed"
    exit 1
  fi 

  # Give the nic an ip address
  if [ ! -z ${NICADDRESS} ] ; then
    echo "[INFO] set IP of ${NICTOMAP} to ${NICADDRESS}"
    $SUDO ip netns exec ${RUNTIMEID} ip address add $NICADDRESS dev ${NICTOMAP}
    if [ $? -ne 0 ] ; then
      echo "[Error] set ip address failed"
      exit 1
    fi 
  fi
fi

# Wait for the runtime to start or for the timeout incase something went wrong
INTERVAL=5
TIMEOUT=60
COUNTER=0  
while ! docker logs ${RUNTIMEID} | grep "Codesyscontrol starting" 1>/dev/null 2>/dev/null && [ $COUNTER -lt $TIMEOUT ]
do 
  echo "[INFO] waiting for start of runtime"
  sleep $INTERVAL
  ((COUNTER+=$INTERVAL))
done

# Check if startup was successful
if docker logs ${RUNTIMEID} | grep "Codesyscontrol starting" 1>/dev/null 2>/dev/null ; then
  echo "[INFO] start triggered"
else
  echo "[ERROR] start not triggered"
  exit 1
fi

exit 0
