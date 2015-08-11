$deps = [
    'git',
    'iptables',
    'wget',
    'unzip',
    'net-tools',
    'bridge-utils',
    'patch',
]

$hosts = hiera('hosts')

file { '/etc/hosts':
   ensure  => file,
   owner   => 'root',
   group   => 'root',
   content => template('/vagrant/puppet/templates/hosts.erb')
}

package { $deps:
    ensure   => installed,
}

file { "/opt":
    ensure => "directory",
    owner  => "root",
    group  => "root",
    mode   => 777,
}

vcsrepo {'/opt/tools':
    ensure   => present,
    provider => git,
    user     => 'vagrant',
    source   => 'https://github.com/shague/odl_tools.git',
    require  => File['/opt'],
}

# Flush iptables, so stack has a clean slate
#
exec { 'Flush iptables':
    command => '/sbin/iptables -F',
    user    => 'root',
    require => Package[$deps],
    onlyif  => ['/usr/bin/test -f /sbin/iptables'],
}
exec { 'Flush iptable chain':
    command => '/sbin/iptables -X',
    user    => 'root',
    require => Exec['Flush iptables'],
    onlyif  => ['/usr/bin/test -f /sbin/iptables'],
}
exec { 'Save iptable':
    command => '/usr/sbin/service iptables save',
    user    => 'root',
    require => Exec['Flush iptable chain'],
    onlyif  => ['/usr/bin/test -f /sbin/iptables'],
}
