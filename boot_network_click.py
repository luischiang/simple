#!/usr/bin/python

# Cheng-Chun Tu
# Dec 27, 2012
# Dec 28, merge code with Luis
# Jan 16, integate with new Topo file and POX 

"""
This example creates a multi-controller network from
semi-scratch; note a topo object could also be used and
would be passed into the Mininet() constructor.
"""
import sys
import random
import os
import time
from mininet.net import Mininet
from mininet.node import Controller, OVSKernelSwitch, RemoteController
from mininet.cli import CLI
from mininet.log import setLogLevel
from mininet.link import Intf
from mininet.log import setLogLevel, info, error, debug
from mininet.term import cleanUpScreens, makeTerm

Switch = OVSKernelSwitch

#	Hosts		(hoX)		00:00:11:00:0X:0Y	11.0.X.Y
#	Switches	(swX)		00:00:12:00:0X:0Y	12.0.X.Y
#	MiddleBoxes (mbX)		00:00:13:00:0X:0Y	13.0.X.Y

def print_ifconfig(node_list):
	for nd in node_list:
		print nd.cmd("ifconfig")


class TopoFile:
	"""
	S2 M1 1
	"""
	def add_node(self, nodename):
		""" node type, the first character is type: {S, M, H} """
		if nodename.startswith("S"):
			if nodename not in self.sw_list: self.sw_list.append(nodename)		
		elif nodename.startswith("H"):
			if nodename not in self.host_list: self.host_list.append(nodename)
		elif nodename.startswith("M"):
			if nodename not in self.mb_list: self.mb_list.append(nodename)
		else:
			print "Error when add_node:", nodename
			sys.exit(1)
	
	def add_edge(self, n1, n2):
		""" 
		input: n1="S1", n2="S9", output: [("S1 S2"), ("H1", "S1") ... ]
		"""	
		if (n1, n2) in self.edge_list: return
		if (n2, n1) in self.edge_list: return
		self.edge_list.append((n1,n2))

	def __init__(self, edge_file):
		
		self.edge_file = edge_file
		self.sw_list = []
		self.mb_list = []
		self.host_list = []
		self.edge_list = []

		edgef = open(self.edge_file)
		for line in edgef:
			if line.startswith("NUM"): continue
			if line.startswith("#"): continue
		
			elem = line.split()	
			self.add_node(elem[0])
			self.add_node(elem[1])
			self.add_edge(elem[0], elem[1])

	def __str__(self):	
		return "under construction"

	def dump(self):
		print "host ID:", self.host_list
		print "switch ID:", self.sw_list
		print "MB ID:", self.mb_list
		print "Edge:", self.edge_list

def addMiddleBox(net, name):
	"Create MiddleBox mbN and add to net."
	ip = '13.0.%d.2' % int(name[1:])
	mb = net.addHost(name, ip=ip)
	return mb
	
def addHost(net, name):
	"Create host hN and add to net."
	ip = '11.0.%d.2' % int(name[1:])
	ho = net.addHost(name, ip=ip)
	return ho

def addSwitch(net, name):
	return net.addSwitch(name)

def TopologyHotnet(networkName, edgefile, configfile):
	"Create a network with multiple controllers."
	 
	net = Mininet( controller=RemoteController, switch=Switch, autoSetMacs = True)
	print "*** Creating controllers"
	c1 = net.addController('c1', port=7799, ip="127.0.0.1")

	swobj_dict = {}
	hobj_dict = {}
	mbobj_dict = {}
	allobj = {}

	print "*** read topology from file"
	tf = TopoFile(edgefile)
	tf.dump()
	
	# Add switches
	for sw_name in tf.sw_list:
		sw = addSwitch(net, sw_name)
		swobj_dict[sw_name] = sw
		print "add switch: ", sw
	
	# Add Host 
	for host_name in tf.host_list:
		h = addHost(net, host_name) 
		hobj_dict[host_name] = h
		print "add host: ", h

	# Add MB
	for mb_name in tf.mb_list:
		m = addMiddleBox(net, mb_name)
		mbobj_dict[mb_name] = m
		print "add middlebox: ", m

	allobj["S"] = swobj_dict
	allobj["H"] = hobj_dict
	allobj["M"] = mbobj_dict

	# Add edges 
	for edge in tf.edge_list: 
		(n1, n2) = edge
		ntype1 = n1[0]
		ntype2 = n2[0]
		node1 = allobj[ntype1][n1]
		node2 = allobj[ntype2][n2]
		print "add link between two node : ", n1, n2
		net.addLink(node1, node2)

	# Configure the MAC address
	for sw_name in tf.sw_list:
		sw = swobj_dict[sw_name]
		swid = int(sw_name[1:])
		mac = 0
		for intfname in sw.intfList():
			if swid < 100:
				sw.setMAC('00:00:12:00:%d:%d' % (swid, mac), intfname)
			else:
				sw.setMAC('00:00:12:01:%d:%d' % (swid-100, mac), intfname)
			mac = mac + 1

	print "*** Starting network"
	net.build()
	
	time.sleep(2)
	 
	for key in swobj_dict.keys():
		sw = swobj_dict[key]
		time.sleep(0.5)
		sw.start([c1])

	print "*** Sleep for reaching the controller (10 seconds)"
	time.sleep(10)
	 
	print "*** View network"
	 
	for host_name in tf.host_list:
		ho = hobj_dict[host_name]
		for intfname in ho.intfList():
			print '%s %s %s %s' % (ho.name, ho.IP(intfname), ho.MAC(intfname), intfname)
			
	for mb_name in tf.mb_list:
		mb = mbobj_dict[mb_name]
		for intfname in mb.intfList():
			print '%s %s %s %s' % (mb.name, mb.IP(intfname), mb.MAC(intfname), intfname)
	
	print "*** configuring hosts"
	
	configlines = open(configfile, 'r')
	
	for host_name in tf.host_list:
		ho = hobj_dict[host_name]
		for x in range(1,5):
			linecmd = configlines.readline()
			ho.cmd(linecmd.strip(' \t\n\r'))
		
	configlines.close()
	
	print "*** configuring middleboxes"
	 
	for mb_name in tf.mb_list:
		mb = mbobj_dict[mb_name]
		mb.cmd("click /home/luis/finalmbox/clickfiles/%s/%s-eth0.click &" % (networkName, mb.name))
		
	print "*** running iperf clients"
	 
	for host_name in tf.host_list:
		ho = hobj_dict[host_name]
		#ho.cmd("/home/luis/finalmbox/iperf/%s/%s.sh &" % (networkName, ho.name) )
		#net.terms += makeTerm(ho)
	
	print "*** Running CLI"
	CLI( net )
	 
	print "*** Stopping network"
	#cleanUpScreens()
	net.stop()
	
	os.system("/home/luis/finalmbox/terminate_experiments.sh")

if __name__ == '__main__':
	setLogLevel( 'info' )  # for CLI output
	
	if len(sys.argv) != 4:
		print "Usage: ./ThisProgram <NetworkName> <Topology_xxx> <config_xxx.txt>"
		print "ex: abilene Topology_abilene config_abilene.txt" 
		sys.exit(1)

	TopologyHotnet(sys.argv[1], sys.argv[2], sys.argv[3])
