class ipeer::db(
  $root_password = 'secretpassword',
  $backup = false,
  $databases = {},
) {
  class {'db::mysql':
    root_password => $root_password,
    backup => $backup,
    databases => $databases,
  } ->

  Mysql::Db <<| tag == $domain |>>

  # export resource to be used by web instance
  #$db_host = $fqdn
  #@@file {"/etc/ipeerdb.${domain}.php":
  #  ensure => present,
  #  content => template('ipeer/database.php.erb'),
  #  tag => $domain
  #}

  # looking for the web servers to grant access to the database
  #$ips = query_nodes("fqdn~\"$domain\" and Class[ipeer::web]", 'ipaddress')
  #if $ips {
  #  $ips.each |$ip| {
  #    create_resources('mysql_user', 
  #      {"${db_username}@${ip}" => {password_hash => mysql_password($db_password)}})
  #    create_resources('mysql_grant', 
  #      {"${db_username}@${ip}/${db_name}.*" => {user => "${db_username}@${ip}"}}, 
  #      { ensure => present, privileges => ['ALL'], table => "${db_name}.*"})
  #  }  
  #}
}
