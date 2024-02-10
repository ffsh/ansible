#! python3

import subprocess
import sys
import re

pattern = re.compile(r"(batman-adv)(?:, |\/)(\d{4}.\d).*installed")

dkms = subprocess.check_output(["dkms", "status", "batman-adv"]).decode("utf-8")

result = pattern.match(dkms)

print(result[2], end="")