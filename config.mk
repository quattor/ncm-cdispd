#
# configuration values for the component
#

COMP=ncm-cdispd

NAME=$(COMP)
DESCR=ncm-cdispd is the Configuration Dispatch Daemon
VERSION=1.2.0
RELEASE=1

AUTHOR=Rafael A. Garcia Leiva
MAINTAINER=Juan Antonio Lopez Perez <Juan.Lopez.Perez@cern.ch>, German Cancio Melia <German.Cancio.Melia@cern.ch>

CONFIGFILE=$(QTTR_ETC)/ncm-cdispd.conf

TESTVARS=

LOCKFILE=$(QTTR_LOCKD)/ncm-cdispd


TARFILE=ncm-cdispd-1.1.14.src.tgz
PROD=\#
DATE=10/06/10 15:49
