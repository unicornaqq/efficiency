#!/usr/bin/python
import os
import string
import subprocess
import shlex
import sys
import time

#output example
#07:28:44 root@BR-H1002-spa spa:~> ps -A | grep safe
# 1766 ?        00:02:49 csx_ic_safe
#hostconfcli display ports | grep "Entry: 04"

#PROCNAME = sys.argv[1]

def is_iscsiport_ready():
	print "check the readiness of the iscsi port..."
	command_line = '/opt/safe/safe_binaries/user/exec/HostConfCli.exe display ports | grep "Entry: 04"'
	sp = subprocess.Popen(command_line,stderr=subprocess.PIPE,stdout=subprocess.PIPE,shell=True)
	out = sp.communicate()[0]
	if out:
		print out
		port_up = string.find(out,"Up")
		if port_up == -1:
			return 0
		else:
			return 1
	else:
		return 0
		

PROCNAME = "safe"
command_line = 'ps -A | grep ' + PROCNAME

while True:
	sp = subprocess.Popen(command_line,stderr=subprocess.PIPE,stdout=subprocess.PIPE,shell=True)
	out = sp.communicate()[0]
	if out:
		print "safe is ready, wait for the up of the iscsi port..." 
		while True:
			if is_iscsiport_ready():
				break
			print "iscsiport is not ready"
			time.sleep(10)
		# The iscsi port is ready for the ql FW dump now
		os.system("/EMC/Platform/bin/svc_rescue_state -c")
		os.system("/root/livedebug.pl -c safe")
		break
	else:	
		print "safe is not ready..."
		time.sleep(10)	

