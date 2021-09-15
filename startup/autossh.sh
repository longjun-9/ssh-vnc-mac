#!/bin/bash
autossh -M 0 -fNR 3000:localhost:5900 -F /Users/admin/.ssh/config -i /Users/admin/.ssh/id_rsa -o ServerAliveInterval=60 -o ServerAliveCountMax=3 ExitOnForwardFailure=yes SSHServer