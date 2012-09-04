from setuptools import setup, find_packages
import glob
import os

version = '0.23'
name = 'slapprepare'


setup(name=name,
      version=version,
      description="SlapOS SetUP kit.",
      classifiers=[
          "Programming Language :: Python",
        ],
      keywords='slapos Setup Kit',
      license='GPLv3',
      packages=['slapprepare'],
      include_package_data=True,
      zip_safe=False, # proxy depends on Flask, which has issues with
                      # accessing templates
      entry_points={
        'console_scripts': [
      'slapprepare = slapprepare:slapprepare',
      'slapupdate = slapprepare.slapupdate:main',
      ]
        },
      )
