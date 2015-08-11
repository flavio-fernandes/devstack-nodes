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

