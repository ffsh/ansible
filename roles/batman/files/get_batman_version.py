#! python3

import subprocess
import sys
import re

# compile regex for installed batman version
pattern = re.compile(r"(batman-adv)(?:, |\/)(\d{4}.\d).*installed")

# check for batman-adv packages
dkms = subprocess.check_output(["dkms", "status", "batman-adv"]).decode("utf-8")

# use regex to find installed version
result = pattern.match(dkms)

# print only the version, without newline otherwise ansible will store the newline
print(result[2], end="")