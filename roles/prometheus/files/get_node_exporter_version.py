#! python3

import subprocess
import sys
import re

# compile regex for installed node_exporter version
pattern = re.compile(r"node_exporter, version (\d\.\d\.\d)")

# check current node_exporter
node_exporter = subprocess.check_output(["/opt/node_exporter/node_exporter", "--version"]).decode("utf-8")

# use regex to find installed version
result = pattern.match(node_exporter)

if result:
    # print only the version, without newline otherwise ansible will store the newline
    print(result[1], end="")
else:
    print("not_installed", end="")