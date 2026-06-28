import sys
import re

def main():
    path = 'ios/Runner.xcodeproj/project.pbxproj'
    try:
        with open(path, 'r') as f:
            content = f.read()

        # 1. Remove DevelopmentTeam from TargetAttributes
        content = re.sub(r'DevelopmentTeam = [A-Z0-9]+;', 'DevelopmentTeam = "";', content)

        # 2. Set DEVELOPMENT_TEAM to empty string in all build settings
        content = re.sub(r'DEVELOPMENT_TEAM = [A-Z0-9"]+;', 'DEVELOPMENT_TEAM = "";', content)

        # 3. Force CODE_SIGNING_ALLOWED to NO
        if 'CODE_SIGNING_ALLOWED' in content:
            content = re.sub(r'CODE_SIGNING_ALLOWED = YES;', 'CODE_SIGNING_ALLOWED = NO;', content)
        else:
            # Inject it into buildSettings if missing
            content = content.replace('buildSettings = {', 'buildSettings = {\n\t\t\t\tCODE_SIGNING_ALLOWED = NO;')

        # 4. Force CODE_SIGNING_REQUIRED to NO
        if 'CODE_SIGNING_REQUIRED' in content:
            content = re.sub(r'CODE_SIGNING_REQUIRED = YES;', 'CODE_SIGNING_REQUIRED = NO;', content)
        else:
            content = content.replace('buildSettings = {', 'buildSettings = {\n\t\t\t\tCODE_SIGNING_REQUIRED = NO;')

        # 5. Ensure CODE_SIGN_IDENTITY is empty
        content = re.sub(r'CODE_SIGN_IDENTITY = ".*?";', 'CODE_SIGN_IDENTITY = "";', content)
        content = re.sub(r'CODE_SIGN_IDENTITY = .*?;', 'CODE_SIGN_IDENTITY = "";', content)

        # 6. Force Manual signing style
        content = re.sub(r'CODE_SIGN_STYLE = Automatic;', 'CODE_SIGN_STYLE = Manual;', content)

        # 7. Remove any provisioning profiles
        content = re.sub(r'PROVISIONING_PROFILE_SPECIFIER = ".*?";', 'PROVISIONING_PROFILE_SPECIFIER = "";', content)
        content = re.sub(r'PROVISIONING_PROFILE = ".*?";', 'PROVISIONING_PROFILE = "";', content)

        with open(path, 'w') as f:
            f.write(content)
        print("Successfully cleaned project.pbxproj")
    except Exception as e:
        print(f"Error cleaning pbxproj: {e}")

if __name__ == '__main__':
    main()
