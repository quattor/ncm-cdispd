@{ Template for testing ncm-cdispd utility funtions (CDISPD::Utils.pm) }

unique template base2;

include 'base1';

prefix '/software/components/named';
'servers/0' = '134.158.88.149';


prefix '/software/components/ccm';
'active' = false;
'register_change' = null;

prefix '/software/components/ldconf';
'active' = true;
'register_change/0' = '/system/kernel/version';

'/software/components/dirperm' = null;

prefix '/software/components/dpmlfc';
'active' = true;
'dependencies/pre/0' = 'spma';
'dispatch' = true;


prefix '/software/packages';
'{ncm-dirperm}' = null;
'{ncm-dpmlfc}' = dict();


prefix '/software/repositories';
'name' = 'ca';
