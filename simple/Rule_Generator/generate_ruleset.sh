#!/bin/bash

#LC: Fix to allow execute from another program without changing the references
cd "$(dirname "$0")"

perl simpletorule.pl Config_Dynamic dynamic_route_output.txt simple_200Dynamic.sol switches.txt hosts.txt
