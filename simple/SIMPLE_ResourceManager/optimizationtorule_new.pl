#! /usr/bin/perl

use strict;
use POSIX;
require "inputfileparse.pl";
require "shortestpathutils.pl";
require "policyutils.pl";

if ($#ARGV < 4)
{
	die "usage: configfile segmentoutput optimization_solution switch_info host_info \n";
}


## read the config with 4 inputs -- policy, topology, mbox, switch
my $configfile = $ARGV[0];
my $outfile = $ARGV[1];
my $switchinfo = $ARGV[3];
my $hostinfo = $ARGV[4];
open (f,"<$configfile") or die "Cant read configfile\n";
my $data = "";
my $topologyfile = "";
my $policyfile = "";
my $mboxinventory = "";
my $switchinventory = "";
my %switch_table = ();
my $flag = -4;
while ($data = <f>)
{
	chomp($data);
	## topology
	if ($data =~/TOPOLOGY\s+(.*)/)
	{
		$topologyfile =$1;
		$flag++;
	}
	## policy req
	if ($data =~/POLICY\s+(.*)/)
	{
		$policyfile =$1;
		$flag++;
	}
	## mboxtypes
	if ($data =~/MBOXES\s+(.*)/)
	{
		$mboxinventory =$1;
		$flag++;
	}
	## switch resources
	if ($data =~/SWITCHES\s+(.*)/)
	{
		$switchinventory =$1;
		$flag++;
	}
}
close(f);

## read the input files
	
my ($TopologyNameRef,$TopologyIDRef,$NodeNametoIDRef, $NodeIDtoNameRef,$NumSwitches,$NumBoxes,$NumHostNodes) = read_topology($topologyfile);
my ($ClassID2PolicyChainRef, $ClassID2HostsRef,$ClassID2VolumeRef) = read_policy_chains($policyfile);
my ($MboxName2TypeRef, $MboxType2SetRef, $MboxResourcesRef) = middlebox_inventory($mboxinventory);
my ($SwitchResourcesRef) = switch_inventory($switchinventory);

# Getting the host, mb and switch information
my ($SwitchPortInfo, $SwitchMacInfo) = get_sw_info($switchinfo);
my ($HostMbIpInfo, $HostMbMacInfo) = get_hs_mb_info($hostinfo);



my $NumNodes = $NumSwitches+$NumBoxes+$NumHostNodes;

## generate shortest paths
my $PathsRef  =  dijkstra_shortest_paths($NumNodes, $TopologyIDRef);


## generate physical chains at middlebox sequence granularity -- e.g., M1 -->  M2
my $outfile_chains = "/tmp/junk";
my ($SequencesPerClass,$NumSequencesPerClass,$MboxInClassSequenceRef)  = enumerate_physical_sequences($ClassID2PolicyChainRef,$MboxType2SetRef,$outfile_chains);

my ($RoutesPerSequencePerClassRef, $SwitchInClassSequenceRef) = get_switch_cost_per_sequence($ClassID2PolicyChainRef,$ClassID2HostsRef,$SequencesPerClass, $NumSequencesPerClass, $NodeNametoIDRef, $NodeIDtoNameRef,$PathsRef);

# Added by Zafar
#my $PrunedSet = greedy_pruning_sequenceset( $SequencesPerClass, $NumSequencesPerClass, $RoutesPerSequencePerClassRef, $NodeIDtoNameRef,$ClassID2VolumeRef, $SwitchResourcesRef,$MboxResourcesRef );
my @data = `cat $ARGV[2] | awk '{if(\$1=="<variable") print \$2}' | awk -F"=" '{print \$2}'`;
my @data_value = `cat $ARGV[2] | awk '{if(\$1=="<variable") print \$4}' | awk -F"=" '{print \$2}'`;


# Contains the fraction of traffic on each physical middlebox sequence: Solution of optmization problem
my %flow_table = ();
my %ActiveSet = ();

# Filling up the flow table from the optmization solution file
my $i = 0;

for($i=0; $i < @data; $i++)
{
        chomp($data[$i], $data_value[$i]);
        my ($trash, $flow_no, $trash_1) = split(/"/,$data[$i]);
        chomp ($flow_no);
        #print "$flow_no  \n";
        my($trash, $flow_value, $trash_1) = split(/"/,$data_value[$i]);
        chomp ($flow_value);
        #print "$flow_value  \n";

        chomp ($flow_value);
        if ($flow_no =~ m/f_.*_.*/)
        {
                $flow_table{$flow_no} = $flow_value;
        }
}



my $flow_key = 0;
foreach $flow_key (sort keys %flow_table)
{

        if($flow_table{$flow_key} != 0)
        {

                my ($ftag, $classid, $seqid1) = split(/\_/,$flow_key);
                #print "$ftag, $class, $seqid\n";
                chomp($ftag, $classid, $seqid1);
                #print "Class = $class, Sequence = $seqid \n";
                $ActiveSet{$classid}->{$seqid1}=1;


        }

}

open(out,">$outfile");



my $class = 0;
foreach $class (sort {$a<=>$b} keys %ActiveSet)
{
	my $seqid = 0;
	my $i = 0;
	foreach $i (keys %{$ActiveSet{$class}})
	{
		#print "$i \n";
		my $path = $RoutesPerSequencePerClassRef->{$class}->[$i];
		my $pathnames = convert_path_ids_to_names($path,$NodeIDtoNameRef);
	        #print out "$class $i Route = $path $pathnames\n";
		## split into segments
		
		my @pathelements = split(/\s+/,$pathnames);
		my @path = split(/\s+/,$path);
		my $dl_src = "";
		my $dl_dst = "";
		my $in_port = 0;
		my $nw_src = "";
		my $nw_dst = "";
		my $mod_dl_src = "";
		my $mod_dl_dst = "";
		my $output = 0;
		my $nw_tos = "Ox20";
		my $mod_nw_tos = "0x20";
		my $host_src_id = "";
		my $host_dst_id = "";
		my $dl_type= "0x0800";
		my $sw_id = "";
		my $node_id = "";		
		my $rule = "";
		my $sw_id = "";
		my $switch_id = "";
		my $nw_src_rv = "";
		my $nw_dst_rv = "";


		# Network src and destination address
		my($trash, $id)  = split(//,$pathelements[0]);
		$host_src_id = "ho".$id;
		$nw_src = $HostMbIpInfo->{$host_src_id};
		$nw_dst_rv = $nw_src;
		#print "$nw_src \n";
		my($trash, $id) = split(//,$pathelements[$#pathelements]);
		$host_dst_id = "ho".$id;
                $nw_dst = $HostMbIpInfo->{$host_dst_id};
		$nw_src_rv = $nw_dst;
                #print "$nw_dst \n";



		#print out "Class=$class,Sequence=$i,Segment=$segmentid;"; 
		for (my $j =0; $j <= $#pathelements; $j++)
		{
			## segment ends at a mb
			#print out " $pathelements[$j]";



			if ($pathelements[$j] =~ /^S(\d+)/)
			{
				my($trash, $id)  = split(//,$pathelements[$j]);
				$sw_id = "sw".$id;
				$switch_id = $id;
				
				# Start adding a rule in the switch
				# First identify whether the switch is connected to a host, middlebox or another switch
				if ($pathelements[$j-1] =~ /^S(\d+)/)
				{
					my($trash, $id)  = split(//,$pathelements[$j-1]);
					$node_id = "sw".$id;
					$dl_src = $SwitchMacInfo->{$node_id}->{$sw_id};
                			$dl_dst = $SwitchMacInfo->{$sw_id}->{$node_id};
					$in_port = $SwitchPortInfo->{$sw_id}->{$node_id};
					
					# Setup the reverse path
					


				}


				if ($pathelements[$j-1] =~ /^H(\d+)/)
                                {
                                        my($trash, $id)  = split(//,$pathelements[$j-1]);
                                        $node_id = "ho".$id;
                                        $dl_src = $HostMbMacInfo->{$node_id};
                                        $in_port = $SwitchPortInfo->{$sw_id}->{$node_id};
					$dl_dst = $SwitchMacInfo->{$sw_id}->{$node_id};
					

					#Setup the reverse path

                                }


				if ($pathelements[$j-1] =~ /^M(\d+)/)
                                {
                                        my($trash, $id)  = split(//,$pathelements[$j-1]);
                                        $node_id = "mb".$id;
                                        $dl_src = $HostMbMacInfo->{$node_id};
                                        $in_port = $SwitchPortInfo->{$sw_id}->{$node_id};
                                        $dl_dst = $SwitchMacInfo->{$sw_id}->{$node_id};

					#Setup the reverse path

                                }

				if ($pathelements[$j+1] =~ /^S(\d+)/)
                                {
                                        my($trash, $id)  = split(//,$pathelements[$j+1]);
                                        $node_id = "sw".$id;
                                        $mod_dl_src = $SwitchMacInfo->{$sw_id}->{$node_id};
                                        $mod_dl_dst = $SwitchMacInfo->{$node_id}->{$sw_id};
                                        $output = $SwitchPortInfo->{$node_id}->{$sw_id};

					#Setup the reverse path

                                }


                                if ($pathelements[$j+1] =~ /^H(\d+)/)
                                {
                                        my($trash, $id)  = split(//,$pathelements[$j+1]);
                                        $node_id = "ho".$id;
                                        $mod_dl_dst = $HostMbMacInfo->{$node_id};
                                        $output = $SwitchPortInfo->{$sw_id}->{$node_id};
                                        $mod_dl_src = $SwitchMacInfo->{$sw_id}->{$node_id};

					#Setup the reverse path

                                }


                                if ($pathelements[$j+1] =~ /^M(\d+)/)
                                {
                                        my($trash, $id)  = split(//,$pathelements[$j+1]);
                                        $node_id = "mb".$id;
					$mod_dl_dst = $HostMbMacInfo->{$node_id};
                                        $output = $SwitchPortInfo->{$sw_id}->{$node_id};
                                        $mod_dl_src = $SwitchMacInfo->{$sw_id}->{$node_id};

					#Setup the reverse path

                                }


				$rule = "dl_type=".$dl_type.", "."dl_src=".$dl_src.", "."dl_dst=".$dl_dst.", "."in_port=".$in_port.", "."nw_src=".$nw_src.", "."nw_dst=".$nw_dst.", "."actions="."mod_dl_src:".$mod_dl_src.", "."mod_dl_dst:".$mod_dl_dst.", "."output:".$output;	
				#print "$rule \n";
				$switch_table{$switch_id} = $switch_table{$switch_id}. "\n ". $rule. "\n";

				#print out "\n";
				#$segmentid++;
				#print out "Class=$class,Sequence=$i,Segment=$segmentid;"; 
			}
		}
		#print out "\n";
	} 

}

close(out);


# The switch table contains the rules to be installed at each switch
# Parse each path, adding rules in the switch on the path


my $key= "";
foreach $key (sort{$a<=>$b} keys %{switch_table})
{
 print "Switch$key \n $switch_table{$key} \n \n";

}







