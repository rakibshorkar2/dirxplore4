import re
import sys

def clean_pbxproj(path):
    with open(path, 'r') as f:
        lines = f.readlines()

    with open(path, 'w') as f:
        for line in lines:
            # Remove all DEVELOPMENT_TEAM lines
            if 'DEVELOPMENT_TEAM' in line:
                continue
            # Remove all PROVISIONING_PROFILE lines
            if 'PROVISIONING_PROFILE' in line:
                continue
            # Force Code Sign Style to Manual
            if 'CODE_SIGN_STYLE' in line:
                line = re.sub(r'CODE_SIGN_STYLE = (Automatic|""|null);', 'CODE_SIGN_STYLE = Manual;', line)

            # Force identity to empty
            if 'CODE_SIGN_IDENTITY' in line:
                line = re.sub(r'CODE_SIGN_IDENTITY = ".*";', 'CODE_SIGN_IDENTITY = "";', line)

            f.write(line)

if __name__ == "__main__":
    clean_pbxproj('ios/Runner.xcodeproj/project.pbxproj')
