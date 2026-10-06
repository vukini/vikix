A port is a numbered door on this machine, one of 65,536, that a program opens to take connections: the web on 443, ssh on 22, the desktop's Swank on 4004. One open to the network is reachable by any machine that can reach this one; one open to this machine only, by its own programs.

guide: fixing.md#Something on the network can't reach this computer
manual: ss(8)
manual: services(5)
see: process
see: service
