iPeer Puppet Module
-------------------

This module installs iPeer with Nginx.

Dependencies
------------
Puppet 3.2+ with parser=future enabled
* stdlib
* jfryman/puppet-nginx
* theforeman/puppet-git
* puppetlabs/puppetlabs-vcsrepo 
* mayflower/puppet-php
* puppetlabs/puppetlabs-firewall
* puppetlabs/puppetlabs-mysql
* puppetlabs/puppetlabs-concat

Optional:
* dalen/puppet-puppetdbquery 
* puppetlabs/puppetlabs-apt (needed on Debain and its variants)

This module has been tested in RHEL 6.4.
