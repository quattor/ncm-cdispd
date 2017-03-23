BEGIN {
    our $TQU = <<'EOF';
[load]
prefix=CDISPD::
modules=Application,Utils
[doc]
poddirs=target/lib/perl,target/sbin
panpaths=NOPAN
EOF
}
use Test::Quattor::Unittest;
