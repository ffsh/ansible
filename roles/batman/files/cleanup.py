#! python3

import subprocess
import sys
import re
import shutil

# Name of the DKMS module
module_name = "batman-adv"

def delete_directory(directory):
    try:
        shutil.rmtree(directory)
        print("Directory deleted successfully!")
    except OSError as error:
        print("Error deleting directory:", error)
        sys.exit(1)

# Retrieve the desired version from command line input
desired_version = sys.argv[1]

# Compile regular expressions (once)
pattern = re.compile(r"(?:{})(?:, |\/)(\d{4}.\d)(?::|,)".format(module_name))

# Get a list of installed batman-adv DKMS modules
try:
    installed_modules_output = subprocess.check_output(["dkms", "status", module_name]).decode("utf-8")
    installed_modules = installed_modules_output.splitlines()
except subprocess.CalledProcessError:
    print("Error: Failed to retrieve installed DKMS modules. Check 'dkms status' manually.")
    sys.exit(1)

if not installed_modules:
    print("No installed DKMS modules found.")
    sys.exit(0)

# Iterate through modules add them to set, each module might be installed for multiple kernels, we only need it once
batman_modules = set()

for module in installed_modules:
    # for each found module check if it's a batman module and what version
    match = pattern.match(module)
    if match:
        # Add the found version to the set
        batman_modules.add(match[1])

for module in batman_modules:
        module_version = module[0]
        try:
            if module_version != desired_version:
                # remove module from dkms, this deltes that version from the dkms tree including (--all) all version for the different kernels
                subprocess.call(["dkms", "remove", module_name, "-v", module_version, "--all"])
                print(f"Uninstalled batman_adv version {module_version}")
                # Delete the directory were ansible installs batman-adv
                module_folder = f"/usr/src/{module_name}-{module_version}"
                delete_directory(module_folder)
        except subprocess.CalledProcessError:
            print(f"Error: Module '{module_name}' might not exist or is unavailable for removal.")
            sys.exit(1)

print(f"All batman_adv versions except {desired_version} have been uninstalled (if found).")



