Summary: @DESCR@
Name: @NAME@
Version: @VERSION@
Vendor: EDG / CERN 
Release: @RELEASE@
License: http://www.eu-datagrid.org/license.html
Group: @GROUP@
Source: @TARFILE@
BuildArch: noarch
BuildRoot: /var/tmp/%{name}-build
Packager: @AUTHOR@

Requires: perl-CAF >= 0.1.10
Requires: perl-LC
Requires: ccm >= 1.1.6

%description
@DESCR@


%prep
%setup

%build
make

%install
rm -rf $RPM_BUILD_ROOT
make PREFIX=$RPM_BUILD_ROOT install

# leave log file//
#%postun
#[ $1 = 0 ] && rm -f @NCM_ROTATED@/@NAME@
#exit 0

%files
%defattr(-,root,root)
%attr(755,root,root) @QTTR_SBIN@/ncm-cdispd
%attr(755,root,root) @QTTR_INITD@/ncm-cdispd
%config @QTTR_ETC@/ncm-cdispd.conf
%attr(755,root,root) @QTTR_ROTATED@/ncm-cdispd
%doc @QTTR_DOC@/
%doc @QTTR_MAN@/man@MANSECT@/@COMP@.@MANSECT@.gz


%clean
rm -rf $RPM_BUILD_ROOT

%post
SOname=`uname`
if [ $SOname = "Linux" ] ; then
    if [ "$1" = "1" ] ; then  # first install
        /sbin/chkconfig --add ncm-cdispd 
    fi
    if [ "$1" = "2" ] ; then  # upgrade
        /sbin/service ncm-cdispd restart > /dev/null 2>&1 || :
    fi
fi
if [ $SOname = "SunOS" ] ; then
    #*** We make the startup and shutdown links
    ln -s @QTTR_INITD@/ncm-cdispd /etc/rc2.d/K16ncm-cdispd
    ln -s @QTTR_INITD@/ncm-cdispd /etc/rc3.d/S52ncm-cdispd
    #*** We start the daemon now except if we are installing a new machine
    PGREP_INST=`pgrep -lf wp4.install`
    if [ -z "$PGREP_INST" ] ; then
        @QTTR_INITD@/ncm-cdispd start > /dev/null 2>&1 || :
    fi
fi

%preun
SOname=`uname`
if [ $SOname = "Linux" ] ; then
    if [ "$1" = "0" ] ; then  # last deinstall
        /sbin/chkconfig --del ncm-cdispd
        /sbin/service ncm-cdispd stop > /dev/null 2>&1 || :
    fi
fi
if [ $SOname = "SunOS" ] ; then
    rm /etc/rc2.d/K16ncm-cdispd
    rm /etc/rc3.d/S52ncm-cdispd
    @QTTR_INITD@/ncm-cdispd stop > /dev/null 2>&1 || :
fi
