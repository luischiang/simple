AddressInfo(my_self 0.0.0.0/32 00:00:00:00:00:3b);

in_device	::  FromDevice("M15-eth0");
to_device	::  ToDevice("M15-eth0");
 
in_device -> HostEtherFilter(my_self, DROP_OTHER true, DROP_OWN false) -> EtherMirror() -> Queue(10) -> to_device;