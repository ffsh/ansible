#! python3

import subprocess
import sys
import re
import shutil
import logging

# Name of the DKMS module
module_name = "batman-adv"

# Compile regular expressions
# matches
# older dkms output: batman-adv, 2021.2: ...
# newer dkms output: batman-adv/2023.2, ...
pattern = re.compile(r"(?:batman-adv)(?:, |\/)(\d{4}.\d)(?::|,)")

logger = logging.getLogger("cleanup")

# Log level
logger.setLevel(logging.ERROR)


formatter = logging.Formatter('%(levelname)s - %(message)s')
handler = logging.StreamHandler()  # Writes to the console
handler.setFormatter(formatter)
logger.addHandler(handler)

def delete_directory(directory):
    try:
        shutil.rmtree(directory)
        logger.info("Directory deleted successfully!")
    except OSError as error:
        logger.error("Error deleting directory: %s", error, exc_info=1)
        sys.exit(1)

# Retrieve the desired version from command line input
desired_version = sys.argv[1]
logger.debug("Desired version is : %s", desired_version)

# Get a list of installed batman-adv DKMS modules
try:
    installed_modules_output = subprocess.check_output(["dkms", "status", module_name]).decode("utf-8")
    installed_modules = installed_modules_output.splitlines()
except subprocess.CalledProcessError:
    logger.error("Failed to retrieve installed DKMS modules. Check 'dkms status' manually.", exc_info=1)
    sys.exit(1)

if not installed_modules:
    logger.info("No installed DKMS modules found.")
    sys.exit(0)

# Iterate through modules add them to set, each module might be installed for multiple kernels, we only need it once
batman_modules = set()

for module in installed_modules:
    logger.debug("Checking module: %s", module)
    # for each found module check if it's a batman module and what version
    match = pattern.match(module)
    if match:
        # Add the found version to the set
        logger.debug("Matched %s", match)
        batman_modules.add(match[1])

logger.debug("Found these versions: %s", batman_modules)

for module_version in batman_modules:
        try:
            if module_version != desired_version:
                # remove module from dkms, this deltes that version from the dkms tree including (--all) all version for the different kernels
                subprocess.call(["dkms", "remove", module_name, "-v", module_version, "--all"])
                logger.info("Uninstalled %s version, %s", module_name, module_version)
                # Delete the directory were ansible installs batman-adv
                module_folder = f"/usr/src/{module_name}-{module_version}"
                delete_directory(module_folder)
            else:
                logger.debug("Module version %s is equal to %s", module_version, desired_version)
        except subprocess.CalledProcessError:
            print(f"Error: Module '{module_name}' might not exist or is unavailable for removal.")
            sys.exit(1)

print(f"All batman_adv versions except {desired_version} have been uninstalled (if found).")



