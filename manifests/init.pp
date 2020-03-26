class fahclient (
  String $user,
  String $passkey,
  Integer $team_id,
  Enum['absent', 'present'] $ensure          = 'present',
  Pattern[/^[A-Z]+$/] $cause                 = 'ANY', # ANY includes COVID-19
  Enum['light', 'medium', 'full'] $power     = 'medium',
  Enum['big', 'normal', 'small'] $bigpackets = 'normal', # Memory usage
  Boolean $gpu                               = true,
  Integer $gpu_slots                         = 0, # How many GPUs you have available
  Optional[String] $package_url              = $fahclient::params::package_url, # Set to undef to use your own preconfigured repo
) {

  if $ensure == 'present' {

    if $package_url {
      $package_provider = 'rpm'
      $package_source = $package_url
    } else {
      $package_provider = 'yum'
      $package_source = undef
    }

    package {
      'fahclient':
        ensure   => 'present',
        provider => $package_provider,
        source   => $package_source,
        notify   => Exec['Disable fahclient legacy service'];
    }

    exec {
      'Disable fahclient legacy service':
        user        => 'root',
        command     => '/etc/init.d/FAHClient stop; /usr/bin/mv /etc/init.d/FAHClient /usr/local/sbin',
        provider    => 'shell',
        refreshonly => true;
    }

    file {
      '/lib/systemd/system/fahclient.service':
        ensure  => 'present',
        owner   => 'root',
        group   => 'root',
        mode    => '0444',
        source  => 'puppet:///modules/fahclient/fahclient.service',
        notify  => Exec['Setup fahclient systemd service'],
        require => File['/usr/local/sbin/FAHClient'];

      '/etc/fahclient/config.xml':
        ensure  => 'present',
        owner   => 'fahclient',
        group   => 'root',
        mode    => '0640',
        content => template('fahclient/config.xml.erb'),
        notify  => Service['fahclient'],
        require => Package['fahclient'];

      ['/etc/fahclient', '/var/lib/fahclient']:
        ensure => 'directory',
        owner  => 'fahclient',
        group  => 'root',
        mode   => '0750';

      '/var/run/fahclient.pid':
        owner => 'root',
        group => 'root',
        mode  => '0644';
    }

    exec {
      'Setup fahclient systemd service':
        user        => 'root',
        command     => '/bin/systemctl daemon-reload',
        refreshonly => true;
    }

    service {
      'fahclient':
        ensure  => 'running',
        enable  => true,
        require => Exec['Setup fahclient systemd service'];
    }
  } else {
    package {
      'fahclient':
        ensure => 'absent';
    }

    file {
      ['/etc/fahclient/config.xml', '/etc/systemd/system/multi-user.target.wants/fahclient']:
        ensure => 'absent';
    }
  }
}
