from setuptools import setup, find_packages

# Still under development
version = '0.0.1.3'
name = 'slapos.package'
long_description = open("README.txt").read() + "\n" + \
    open("CHANGES.txt").read() + "\n"

setup(name=name,
      version=version,
      description="SlapOS Package Utils",
      long_description=long_description,
      classifiers=[
          "Programming Language :: Python",
      ],
      keywords='slapos package update',
      license='GPLv3',
      url='http://www.slapos.org',
      author='VIFIB',
      namespace_packages=['slapos'],
      packages=find_packages(),
      include_package_data=True,
      install_requires=[
          'slapos.libnetworkcache',
          'iniparse',
      ],
      zip_safe=False,
      entry_points={
          'console_scripts': [
              # Those entry points are development version
              'slappkg-update = slapos.package.update:main',
              'slappkg-discover = slapos.package.distribution:do_discover',
              'slappkg-upload-key = slapos.package.upload_key:main'
          ],

        # Not supported yet
        #'slapos.cli': [
        #  'package upload-key = slapos.package.upload_key:main'
        #  ]
      },
      test_suite="slapos.package.test",
)
