class ipeer::web(
  $domain,
  $doc_base = "/www_data",
) {
  file { $doc_base:
    ensure => "directory",
  }
  
  file { "/www_config":
    ensure => "directory",
  }
  
  mount { $doc_base:
    device => "10.93.0.3:/data/ipeer/data",
    fstype => "nfs4",
    ensure  => "mounted",
    options => "defaults",
    atboot  => "true",
  }
  
  mount { "/www_config":
    device => "10.93.0.3:/data/ipeer/config",
    fstype => "nfs4",
    ensure  => "mounted",
    options => "defaults",
    atboot  => "true",
  }
  
  include git

  vcsrepo { "$doc_base/html":
    ensure   => latest,
  #  owner    => $owner,
  #  group    => $owner,
    provider => git,
    require  => [ Package["git"] ],
    source   => "https://github.com/ubc/iPeer.git",
    revision => 'master',
  }
  
  file { "$doc_base/html/app/tmp":
    ensure => "directory",
    mode => "0777",
    recurse => true,
  }
  
  
  #################################
  # services
  
  class { 'nginx': }
  
  $nginx_conf_prepend = {
    'if (-f $request_filename)' => '{ break; }',
    'if (-d $request_filename)' => '{ break; }',
  }
  
  $nginx_conf_append = {
    'rewrite' => '^(.+)$ /index.php?url=$1 last;',
  }
  
  nginx::resource::vhost {$domain:
    ensure         => present,
    www_root	   => "$doc_base/html/app/webroot",
    location_cfg_prepend => $nginx_conf_prepend,
    location_cfg_append => $nginx_conf_append,
  }
  
  nginx::resource::upstream { 'ipeer':
    ensure  => present,
    members => [
      '127.0.0.1:9001', 
    ],
  }
  
  nginx::resource::location { 'ipeer':
    ensure => present,
    vhost => $domain,
    location => '~ \.php$',
    fastcgi        => 'ipeer',
    fastcgi_script => "$doc_base/html\$fastcgi_script_name"
  }

  firewall { '100 allow http access':
    port   => [80],
    proto  => tcp,
    action => accept,
  }
  
  php::ini { '/etc/php.ini':
      display_errors => 'Off',
      memory_limit   => '256M',
      date_timezone  => 'America/Vancouver',
  }
  
  include php::cli
  
  php::module { [ 'pecl-apc', 'xml', 'gd', 'ldap', 'mysql']: }
  php::module::ini { 'pecl-apc':
      settings => {
          'apc.enabled'      => '1',
          'apc.shm_segments' => '1',
          'apc.shm_size'     => '32M',
      }
  }
  
  include php::fpm::daemon
  php::fpm::conf { 'www':
      listen  => '127.0.0.1:9001',
      user    => 'nginx',
      # For the user to exist
      require => Package['nginx'],
  }
  
  # php session directory
  file { '/var/lib/php/session':
    ensure => "directory",
    owner => 'nginx',
    group => 'nginx',
  }
}
