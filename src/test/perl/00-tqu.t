BEGIN {
    our $TQU = <<'EOF';
[load]
prefix=CDISPD::
modules=Application,Utils,Main
[doc]
poddirs=target/lib/perl,target/sbin
panpaths=NOPAN
[tt]
basepath=src/main/notresourcessonotttests
EOF
}
use Test::Quattor::Unittest;
