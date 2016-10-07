object template profile2_missing_package;

include 'base1';

# fix intentional missing path in base1 (for other test)
prefix '/software/repositories';
'name' = 'ca';

prefix '/software/packages';
'{ncm-filecopy}' = null;
