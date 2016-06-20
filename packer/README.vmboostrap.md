vm-bootstrap Image
==================

packer vm-boostrap image contain a vm-bootstrap script (see: scripts/vm-bootstrap.sh) which will run in specific bootstrap script when VM boot for the first time.


How it works
------------

Boostrap script is downloaded from a static URL http://10.0.2.100/vm-bootstrap. The script will be executed until it succeed (exit with 0) or until the maximum execution count is reached. By default, the maximum exucution number is 10. To change this value you can write the new value in /root/bootstrap/bootstrap-max-retry.

    #!/bin/bash
    echo 1 > /root/bootstrap/bootstrap-max-retry

    echo "Starting my custom bootstrap commands..."
    ....

To disable bootstrap script execution, remove /root/bootstrap/start-bootstrap from the vm:

    #!/bin/bash
    # temporarily disable bootstrap until XX
    rm -f /root/bootstrap/start-bootstrap

    ...

If no bootstrap script is provided to the vm, an empty script will be generated and will be executed until bootstrap-max-retry=10.

Bootstrap logs are written into file /var/log/vm-bootstrap.log

How boostrap script is downloaded
----------------------------------

Bootstrap script called 'vm-bootstrap' should be placed in and external http server and qemu will be launched with 'guestfwd' option:

    qemu -net 'user,guestfwd=tcp:10.0.2.100:80-cmd:netcat server_ip server_port'

for more information, see qemu 'user network' documentation.
