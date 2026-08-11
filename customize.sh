#!/system/bin/sh
SKIPUNZIP=0
ui_print " "
ui_print "===================================="
ui_print "     Block OTA Update"
ui_print "===================================="
ui_print "v7: Verified Pixel component disable, reversible user-0 changes"
ui_print "Reboot is required so Android Package Manager is fully ready."
ui_print "Commands: su -c blockota enforce | status | resolve | health | scan-smart | report"
ui_print "Recovery: use blockota restore, or create the module-root disable marker from recovery."
