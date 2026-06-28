import os
import re

def patch_pbxproj():
    pbxproj_path = 'ios/Runner.xcodeproj/project.pbxproj'
    if not os.path.exists(pbxproj_path):
        print(f"Error: {pbxproj_path} not found")
        return

    with open(pbxproj_path, 'r') as f:
        content = f.read()

    # 1. Broad regex to clear out any Team IDs
    content = re.sub(r'DevelopmentTeam = [A-Z0-9]+;', 'DevelopmentTeam = "";', content)
    content = re.sub(r'DEVELOPMENT_TEAM = [A-Z0-9"]+;', 'DEVELOPMENT_TEAM = "";', content)

    # 2. Clear provisioning profiles
    content = re.sub(r'PROVISIONING_PROFILE_SPECIFIER = ".*?";', 'PROVISIONING_PROFILE_SPECIFIER = "";', content)
    content = re.sub(r'PROVISIONING_PROFILE = ".*?";', 'PROVISIONING_PROFILE = "";', content)

    # 3. Force ProvisioningStyle to Manual for all targets
    content = re.sub(r'ProvisioningStyle = Automatic;', 'ProvisioningStyle = Manual;', content)
    content = re.sub(r'CODE_SIGN_STYLE = Automatic;', 'CODE_SIGN_STYLE = Manual;', content)

    # 4. Inject aggressive signing disables into ALL build settings blocks
    # We use a unique marker to avoid double-injection if script runs twice
    if 'SIGNED_BY_RAKIB_CLEANER = NO;' not in content:
        content = content.replace(
            'buildSettings = {',
            'buildSettings = {\n\t\t\t\tSIGNED_BY_RAKIB_CLEANER = NO;\n\t\t\t\tCODE_SIGNING_ALLOWED = NO;\n\t\t\t\tCODE_SIGNING_REQUIRED = NO;\n\t\t\t\tCODE_SIGN_IDENTITY = "";\n\t\t\t\tDEVELOPMENT_TEAM = "";'
        )

    with open(pbxproj_path, 'w') as f:
        f.write(content)
    print("Patched project.pbxproj successfully.")

def patch_xcconfig():
    configs = ['ios/Flutter/Debug.xcconfig', 'ios/Flutter/Release.xcconfig']
    for path in configs:
        if os.path.exists(path):
            with open(path, 'w') as f:
                # We overwrite instead of append to ensure clean state
                f.write('#include "Generated.xcconfig"\n\n')
                f.write('CODE_SIGNING_ALLOWED = NO\n')
                f.write('CODE_SIGNING_REQUIRED = NO\n')
                f.write('CODE_SIGN_IDENTITY = \n')
                f.write('DEVELOPMENT_TEAM = \n')
                f.write('PROVISIONING_PROFILE = \n')
                f.write('PROVISIONING_PROFILE_SPECIFIER = \n')
            print(f"Overwrote {path} with unsigned settings.")

if __name__ == "__main__":
    patch_pbxproj()
    patch_xcconfig()
