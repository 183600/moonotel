#!/bin/bash
cd /home/engine/project
python3 full_automation.py 2>&1 | tee /tmp/automation_full.log
exit ${PIPESTATUS[0]}
