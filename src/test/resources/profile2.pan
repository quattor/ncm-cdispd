@{ Template for testing ncm-cdispd utility funtions (CDISPD::Utils.pm) }

object template profile2;

prefix '/software/components/named';

'active' = true;
'dependencies/pre/0' = 'spma';
'dispatch' = true;
'servers/0' = '134.158.88.149';
'servers/1' = '134.158.88.147';
'use_localhost' = true;

prefix '/software/components/spma';

'active' = true;
'cmdfile' = '/var/tmp/spma-commands';
'dispatch' = true;
'packager' = 'yum';
'pkgpaths/0' = '/software/packages';
'process_obsoletes' = false;
'register_change/0' = '/software/repositories';
'register_change/1' = '/software/packages';
'run' = 'yes';

prefix '/software/components/grub';

'active' = true;
'args' = 'crashkernel=128M@16M nohz=off';
'dependencies/pre/0' = 'spma';
'dispatch' = true;
'register_change/0' = '/system/kernel';

prefix '/software/components/ccm';

'active' = false;
'cache_root' = '/var/lib/ccm';
'configFile' = '/etc/ccm.conf';
'debug' = '0';
'dependencies/pre/0' = 'spma';
'dispatch' = false;
'force' = '0';
'get_timeout' = '30';
'lock_retries' = '3';
'lock_wait' = '30';
'profile' = 'http://quattor.web.lal.in2p3.fr/profiles/grid03.lal.in2p3.fr.json';
'retrieve_retries' = '3';
'retrieve_wait' = '30';
'world_readable' = '0';

prefix '/software/components/ldconf';

'active' = true;
'conffile' = '/etc/ld.so.conf';
'dependencies/pre/0' = 'spma';
'dispatch' = true;
'paths/0' = '/usr/lib';
'register_change/0' = '/system/kernel/version';

prefix '/software/components/filecopy';

'active' = true;
'dependencies/post/0' = 'xrootd';
'dependencies/pre/0' = 'spma';
'dispatch' = true;
'forceRestart' = false;
'services/_2fetc_2fat_2eallow/backup' = true;
'register_change/0' = '/software/repositories';

prefix '/software/components/dpmlfc';

'active' = true;
'dependencies/pre/0' = 'spma';
'dispatch' = true;

prefix '/software/packages';

'{ncm-filecopy}' = nlist();
'{ncm-grub}' = nlist();

prefix '/software/repositories';

'name' = 'ca';

prefix '/system/kernel';

'version' = '1.2.3.4.5';

