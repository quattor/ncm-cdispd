@{ Template for testing ncm-cdispd utility funtions (CDISPD::Utils.pm) }

object template broken_profile;

prefix '/software/components/named';

'dependencies/pre/0' = 'spma';
'dispatch' = true;
'servers/0' = '134.158.88.149';
'servers/1' = '134.158.88.147';
'use_localhost' = true;

prefix '/software/components/spma';

'active' = true;
'cmdfile' = '/var/tmp/spma-commands';
'packager' = 'yum';
'pkgpaths/0' = '/software/packages';
'process_obsoletes' = false;
'register_change/0' = '/software/packages';
'register_change/1' = '/software/repositories';
'run' = 'yes';

