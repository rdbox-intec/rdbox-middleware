from setuptools import setup, find_packages
import sys
sys.path.append('./rdbox')
sys.path.append('./tests')

setup(
    name="rdbox",
    version="0.0.25",
    packages=find_packages(),
    test_suite='nose.collector'
)
