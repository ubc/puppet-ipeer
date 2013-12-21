class ipeer::balancer (
  $port = 80,
  $server_name = undef,  
) {
  include epel

  class { 'selinux':
    mode => 'disabled'
  }

  class { 'nginx': 
    confd_purge => true,
  }

  $app_members = query_nodes("fqdn~\"$domain\" and Class[ipeer::web]", 'ipaddress')

  nginx::resource::upstream { 'ipeer_app_cluster':
   ensure  => present,
   members => $app_members,
  }

  #nginx::resource::upstream { 'ipeer_static_cluster':
  # ensure  => present,
  # members => $static_members,
  #}

  nginx::resource::vhost { 'ipeer_balancer':
    ensure   => present,
    proxy    => 'http://ipeer_app_cluster',
    listen_port => $port,
    server_name => $server_name,
    proxy_set_header => ['Host $host', 'X-Real-IP $remote_addr', 'X-Forwarded-For $proxy_add_x_forwarded_for', 'X-Queue-Start "t=${msec}000"']
  }

  #nginx::resource::location { 'ipeer_static_file':
  #  ensure => present,
  #  location => '/ipeer2_course_files',
  #  vhost => 'ipeer_balancer',
  #  proxy => 'http://ipeer_static_cluster',
  #  priority => 450,
  #}

  firewall { '100 allow http access':
    port   => [$port],
    proto  => tcp,
    action => accept,
  }
}

