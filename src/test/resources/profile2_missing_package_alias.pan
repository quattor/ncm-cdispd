object template profile2_missing_package_alias;

include 'base1';

# fix intentional missing path in base1 (for other test)
prefix '/software/repositories';
'name' = 'ca';

@{filecopy is executed by other component module; filecopy package is not included (module provided by other package)}
prefix '/software/components/filecopy';
'ncm-module' = 'somethingelse';

prefix '/software/packages';
'{ncm-filecopy}' = null;
