#!/usr/bin/python

import sys
import random
import os
import time

def getConfiguration(topologyName):
	
	netconfigFile = "netconfig_" +  topologyName + ".txt"
	
	tmpf = open(netconfigFile)
	swlinks = tmpf.readlines()
	tmpf.close()
	
	ifconfigFile = "ifconfig_" + topologyName + ".txt"
	
	tmpf = open(ifconfigFile)
	swmacs = tmpf.readlines()
	tmpf.close()
	
	swlinksPf = {}
	for line in swlinks:
		lineSt = line.strip()
		if lineSt[0] == 'S':
			parts = lineSt.split(" ")
			
			swlinksPf[parts[0]] = []
			for conx in parts[3::]:
				swlinksPf[parts[0]].append(conx.split(":"))
	
	conxFn = "conx_" + topologyName + ".txt"
	conxFile = open(conxFn,"w")
	for sw in swlinksPf:
		i = 1
		for conx in swlinksPf[sw]:
			if conx[1].split("-")[0] == "Tg":
				conxFile.write( "%s\t%s\t%i\t%s\n" % (conx[0].split("-")[0] , conx[0].split("-")[0].replace("S","N") , i ,  getMac(swmacs, conx[0]) ) )
			else:
				conxFile.write( "%s\t%s\t%i\t%s\n" % (conx[0].split("-")[0] , conx[1].split("-")[0] ,  i , getMac(swmacs, conx[0]) ) )
			i = i + 1
	
	conxFile.close()
			
	return 0

def getMac(swmacs, ifname):
	for line in swmacs:
		if ifname in line:
			parts = line.split(" ")
			pos = [i for i,x in enumerate(parts) if x == "HWaddr"]
			return parts[ pos[0] + 1 ]
		
				
if __name__ == '__main__':
	
	if len(sys.argv) != 2:
		print "Usage: ./ThisProgram <NetworkName>"
		print "ex: abilene" 
		sys.exit(1)

	netname = sys.argv[1]
	getConfiguration(netname)
	
