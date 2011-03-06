# This script only works if you are running 1.6.0rc1.  If you are running an older verions, uninstall and reinstall
use flexviews;

select 'Installing stored procedures' as '';
\. install_procs.inc

select 'upgrade done.' as '';
