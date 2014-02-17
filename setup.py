from setuptools import setup

version = '0.0.1.1'
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
      packages=['slapos.package'],
      include_package_data=True,
      install_requires=[
          'slapos.libnetworkcache',
          'iniparse',
      ],
      zip_safe=False,
      entry_points={
          'console_scripts': [
              'slapos-update = slapos.package.update:main',
          ]
      },
      test_suite="slapos.package.test",
)
