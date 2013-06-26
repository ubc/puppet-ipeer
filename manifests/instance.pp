# Definition: ipeer::instance
#
# This class installs iPeer instance
#
# Parameters:

define ipeer::instance (
  $domain,
  $doc_base = "/www_data",
  $port = 80,
  $revision = undef,
  $mount_device = undef,
  $mount_fstype = "nfs4",
) {
  file { $doc_base:
    ensure => "directory",
  }

  if $mount_device {
  mount { $doc_base:
#    device => "10.93.0.3:/data/ipeer/data",
      device => $mount_device,
      fstype => $mount_fstype,
      ensure  => "mounted",
      options => "defaults",
      atboot  => "true",
    }
  }
  

  # if $revision is defined, checkout the source code
  if $revision {
    if ! defined(Class["git"]) {
      include git
    }

    vcsrepo { $doc_base:
      ensure   => latest,
      #owner    => $owner,
      #group    => $owner,
      provider => git,
      require  => [ Package["git"] ],
      source   => "https://github.com/ubc/iPeer.git",
      revision => $revision,
    }
  }

  file { "$doc_base/app/tmp":
    ensure => "directory",
    mode => "0777",
    recurse => true,
  }

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
    listen_port    => $port,
    location_cfg_prepend => $nginx_conf_prepend,
    location_cfg_append => $nginx_conf_append,
  }
  
  nginx::resource::location { $name:
    ensure => present,
    vhost => $domain,
    location => '~ \.php$',
    fastcgi        => 'ipeer',
    fastcgi_script => "$doc_base/html\$fastcgi_script_name"
  }

  if ! defined(Firewall["100 allow $port access"]) {
    firewall { "100 allow $port access":
      port   => $port,
      proto  => tcp,
      action => accept,
    }
  }
}
