SHELL=/bin/sh
PATH=/usr/bin:/usr/sbin:/sbin:/bin
MAILTO=root

*/5 * * * *	root	/opt/slapos/bin/slapgrid-cp /etc/opt/slapos.cfg
*/15 * * * *	root	/opt/slapos/bin/slapgrid-sr /etc/opt/slapos.cfg
0   0 * * *	root	/opt/slapos/bin/slapgrid-ur /etc/opt/slapos.cfg
0 0 * * *	root	/opt/slapos/bin/slapformat /etc/opt/slapos.cfg
