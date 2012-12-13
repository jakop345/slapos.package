import os
import subprocess
import sys


def do_update():
    print 'Updating slapprepare'
    subprocess.call(['easy_install', '-U', 'slapprepare'])


def main():
    if '--no-update' in sys.argv:
        sys.argv.remove('--no-update')
    else:
        do_update()

    args = [
	os.path.join(os.path.dirname(sys.argv[0]), 'slapprepare-raw')
	 ] + sys.argv[1:]

    subprocess.call(args)

