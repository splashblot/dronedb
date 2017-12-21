#!/bin/bash

cd /dronedb
echo "Deleting current assets and node modules..."
rm -rf /public/assets node_modules
echo "Files deleted"
echo "-----------------"
echo "Running bundle (because Compass) and installing dependences"
bundle install
npm install
echo "Dependences installed"
echo "----------------"
echo "Updating cartodb.js"
npm update cartodb.js
echo "----------------"
echo "Running grunt"
grunt
