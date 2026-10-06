A service is a program the machine keeps running for you, without a window: the network, sound, the clock, ssh. On Void, runit starts each one at boot from its folder in /etc/sv, linked into /var/service, and starts it again when it dies. sv-on NAME and sv-off NAME switch one.

guide: customize.md#Programs and services
guide: map.md#Outside your home
guide: fixing.md#Looking for yourself: what the kernel and the system did
manual: sv(8)
manual: runsv(8)
see: process
