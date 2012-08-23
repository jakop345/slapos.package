SHELL=/bin/sh
PATH=/usr/bin:/usr/sbin:/sbin:/bin
MAILTO=root

*/5 * * * *	root	/opt/slapos/bin/slapgrid-cp --verbose --log_file=/opt/slapos/slapgrid-cp.log --pidfile=/opt/slapos/slapgrid-cp.pid  /etc/opt/slapos/slapos.cfg
*/15 * * * *	root	/opt/slapos/bin/slapgrid-sr --verbose --log_file=/opt/slapos/slapgrid-sr.log --pidfile=/opt/slapos/slapgrid-sr.pid /etc/opt/slapos/slapos.cfg
0 0 * * *	root	/opt/slapos/bin/slapgrid-ur --verbose --log_file=/opt/slapos/slapgrid-ur.log  --pidfile=/opt/slapos/slapgrid-ur.pid /etc/opt/slapos/slapos.cfg
0 0 * * *	root	/opt/slapos/bin/slapformat --verbose --log_file=/opt/slapos/slapformat.log /etc/opt/slapos/slapos.cfg
