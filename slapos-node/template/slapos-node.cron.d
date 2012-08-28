SHELL=/bin/sh
PATH=/usr/bin:/usr/sbin:/sbin:/bin
MAILTO=root

*/5 * * * *	root	/opt/slapos/bin/slapgrid-cp --verbose --logfile=/opt/slapos/slapgrid-cp.log --pidfile=/opt/slapos/slapgrid-cp.pid  /etc/opt/slapos/slapos.cfg
*/5 * * * *	root	/opt/slapos/bin/slapgrid-sr --verbose --logfile=/opt/slapos/slapgrid-sr.log --pidfile=/opt/slapos/slapgrid-sr.pid /etc/opt/slapos/slapos.cfg
0 0 * * *	root	/opt/slapos/bin/slapgrid-ur --verbose --logfile=/opt/slapos/slapgrid-ur.log  --pidfile=/opt/slapos/slapgrid-ur.pid /etc/opt/slapos/slapos.cfg
0 0 * * *	root	/opt/slapos/bin/slapformat --verbose  --log_file=/opt/slapos/slapformat.log /etc/opt/slapos/slapos.cfg

# XXX: SlapContainer
*/5 * * * *	root	if [ -x /opt/slapgrid/c436b64d40a48507801d06c53cc27fec/bin/slapcontainer ] ; then /opt/slapgrid/c436b64d40a48507801d06c53cc27fec/bin/slapcontainer --pid /opt/slapos/slapcontainer.pid /etc/opt/slapos/slapos.cfg /opt/slapos/slapcontainer.db > /opt/slapos/slapcontainer.log 2>&1 ; fi
