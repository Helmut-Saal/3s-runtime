#!/bin/bash

###################################################################################################################################################
# To build an image for CODESYS virtual Control the first step is to copy a few files into the same directory on your host machine.
# The files that need to be copied are:
#       Delivery\codesyscontrol_linux_4.5.0.0_amd64.deb
#       Dependency\codemeter-lite_7.40.4990.500_amd64.deb
#       as well as the contents of this folder. (4.5.0.0\virtualControl\)
# All files should be located in the same folder on your host machine, preferably a folder exclusivly for the purpose of building the image.
# After that you can either run the following command or run this script to build your own CODESYS virtual Control image.
###################################################################################################################################################

# docker build . -t <dockerimage_tag> -f <dockerfilename>
docker build . -t codesyscontrol_linux:4.7.0.0 -f Dockerfile_codesyscontrol_linux_*

# The docker image gets build with the name and tag given.
# Continue with DockerRuntimeStart.sh to see how CODESYS virtual Control can be run.
