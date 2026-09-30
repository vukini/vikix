# Services on Void

Void uses runit, not systemd. Every service it knows is a folder in
`/etc/sv/`; the ones running are the links in `/var/service/`.

## Switching one on

    sudo ln -s /etc/sv/sshd /var/service/

runit notices the link within five seconds and starts it, and it starts
again at every boot. `sudo sv status sshd` says whether it's up.

## Switching one off

Remove the link: `sudo rm /var/service/sshd`. To stop it only until the
next boot, `sudo sv down sshd`.
