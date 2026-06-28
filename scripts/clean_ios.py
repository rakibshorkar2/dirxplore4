import os
import re

def patch_pbxproj():
    pbxproj_path = 'ios/Runner.xcodeproj/project.pbxproj'
    if not os.path.exists(pbxproj_path):
        print(f"Error: {pbxproj_path} not found")
        return

    with open(pbxproj_path, 'r') as f:
        content = f.read()

    # Remove Team IDs and Provisioning Profiles
    content = re.sub(r'DevelopmentTeam = [A-Z0-9]+;', 'DevelopmentTeam = "";', content)
    content = re.sub(r'DEVELOPMENT_TEAM = [A-Z0-9"]+;', 'DEVELOPMENT_TEAM = "";', content)
    content = re.sub(r'PROVISIONING_PROFILE_SPECIFIER = ".*?";', 'PROVISIONING_PROFILE_SPECIFIER = "";', content)
    content = re.sub(r'PROVISIONING_PROFILE = ".*?";', 'PROVISIONING_PROFILE = "";', content)

    # Force Manual signing and disable allowed/required signing
    content = re.sub(r'CODE_SIGN_STYLE = Automatic;', 'CODE_SIGN_STYLE = Manual;', content)

    # Inject signing overrides into every BuildSettings block
    # We find where buildSettings starts and inject our keys
    content = content.replace(
        'buildSettings = {',
        'buildSettings = {\n\t\t\t\tCODE_SIGNING_ALLOWED = NO;\n\t\t\t\tCODE_SIGNING_REQUIRED = NO;\n\t\t\t\tCODE_SIGN_IDENTITY = "";'
    )

    with open(pbxproj_path, 'w') as f:
        f.write(content)
    print("Patched project.pbxproj for unsigned build.")

def patch_xcconfig():
    configs = ['ios/Flutter/Debug.xcconfig', 'ios/Flutter/Release.xcconfig']
    for path in configs:
        if os.path.exists(path):
            with open(path, 'a') as f:
                f.write('\nCODE_SIGNING_ALLOWED=NO\n')
                f.write('CODE_SIGNING_REQUIRED=NO\n')
                f.write('CODE_SIGN_IDENTITY=\n')
                f.write('DEVELOPMENT_TEAM=\n')
            print(f"Patched {path}")

if __name__ == "__main__":
    patch_pbxproj()
    patch_xcconfig()
