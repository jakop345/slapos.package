import os
import subprocess
import sys

"""
  Self update the egg every run. It keeps the upgrade system 
  always upgraded.
"""

def do_discover():
  _run_command('slappkg-discover-raw')

def do_update():
  _run_command('slappkg-update-raw')

def do_upload():
  _run_command('slappkg-upload-key-raw')

def _run_command(command):
    if '--no-update' in sys.argv:
        sys.argv.remove('--no-update')
    else:
      print 'Updating slapprepare'
      subprocess.call(['easy_install', '-U', 'slapos.package'])

    args = [
        os.path.join(os.path.dirname(sys.argv[0]), command)
         ] + sys.argv[1:]

    subprocess.call(args)
