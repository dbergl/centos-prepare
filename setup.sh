#!/bin/bash

# make sure curl and wget are available
yum -y install curl wget

# install epel and ius repos
curl -L 'https://setup.ius.io/' | bash

# grab latest package updates
yum -y update
