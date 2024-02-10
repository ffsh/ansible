#! python3

import subprocess
import sys
import re
import shutil

def delete_directory(directory):
    try:
        shutil.rmtree(directory)
        print("Directory deleted successfully!")
    except OSError as error:
        print("Error deleting directory:", error)

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

# Iterate through modules add them to set, each module might be installed for multiple kernels, we only need it once
batman_modules = set()

for module in installed_modules:
    match = pattern.match(module)
    if match:
        batman_modules.add((match[1], match[2]))

for module in batman_modules:
        module_name = module[0]
        module_version = module[1]
        try:
            if module_version != desired_version:
                subprocess.call(["dkms", "remove", module_name, "-v", module_version, "--all"])
                print(f"Uninstalled batman_adv version {module_version}")
                batman_folder = f"/usr/src/{module_name}-{module_version}"
                delete_directory(batman_folder)
        except subprocess.CalledProcessError:
            print(f"Error: Module '{module_name}' might not exist or is unavailable for removal.")

print(f"All batman_adv versions except {desired_version} have been uninstalled (if found).")



