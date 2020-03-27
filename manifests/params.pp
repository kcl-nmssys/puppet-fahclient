# fahclient::params
#
# Distro-specific default settings
#
class fahclient::params {
  case $facts['os']['family'] {
    'RedHat': {
      $package_source_path = 'https://download.foldingathome.org/releases/public/release/fahclient/centos-6.7-64bit/v7.5/fahclient-7.5.1-1.x86_64.rpm'
    }
    default: {
      $package_source_path = undef
    }
  }
}
