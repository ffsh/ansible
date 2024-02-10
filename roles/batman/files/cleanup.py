#! python3

import subprocess
import sys
import re

# Retrieve the desired version from command line input
desired_version = sys.argv[1]

# Compile regular expressions (once)
pattern = re.compile(r"(batman-adv)(?:, |\/)(\d{4}.\d)(?::|,)")

# Get a list of installed DKMS modules
try:
    installed_modules_output = subprocess.check_output(["dkms", "status"]).decode("utf-8")
    installed_modules = installed_modules_output.splitlines()
except subprocess.CalledProcessError:
    print("Error: Failed to retrieve installed DKMS modules. Check 'dkms status' manually.")
    sys.exit(1)

if not installed_modules:
    print("No installed DKMS modules found.")
    sys.exit(0)

# Iterate through the installed modules and remove those that don't match the desired version
for module in installed_modules:
    match = pattern.match(module)
    if match:
        # Extract module name and version
        module_name = match[1]
        module_version = match[2]
        try:
            if module_version != desired_version:
                subprocess.call(["dkms", "remove", module_name, "-v", module_version])
                print(f"Uninstalled batman_adv version {module_version}")
        except subprocess.CalledProcessError:
            print(f"Error: Module '{module_name}' might not exist or is unavailable for removal.")

print(f"All batman_adv versions except {desired_version} have been uninstalled (if found).")



