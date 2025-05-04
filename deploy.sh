#!/bin/bash

# Default values
VERSION_INCREMENT="patch"
COMMIT_MESSAGE="New version release"

# Parse command line arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    --major)
      VERSION_INCREMENT="major"
      shift
      ;;
    --minor)
      VERSION_INCREMENT="minor"
      shift
      ;;
    --patch)
      VERSION_INCREMENT="patch"
      shift
      ;;
    -m|--message)
      COMMIT_MESSAGE="$2"
      shift 2
      ;;
    *)
      echo "Unknown option: $1"
      exit 1
      ;;
  esac
done

echo -e "\e[32mLossPunishment Deployment Script\e[0m"
echo -e "\e[32m---------------------------\e[0m"

# Function to increment semantic version
increment_version() {
    local version=$1
    local increment_type=$2
    
    # Split version into components
    IFS='.' read -r -a parts <<< "$version"
    local major=${parts[0]}
    local minor=${parts[1]}
    local patch=${parts[2]}
    
    case $increment_type in
        "major")
            major=$((major + 1))
            minor=0
            patch=0
            ;;
        "minor")
            minor=$((minor + 1))
            patch=0
            ;;
        "patch"|*)
            patch=$((patch + 1))
            ;;
    esac
    
    echo "$major.$minor.$patch"
}

# 1. Get current version from .toc file
CURRENT_VERSION=$(grep -m 1 "## Version:" LossPunishment.toc | sed 's/## Version: //')
echo -e "\e[36mCurrent version: $CURRENT_VERSION\e[0m"

# 2. Increment version based on parameter
NEW_VERSION=$(increment_version "$CURRENT_VERSION" "$VERSION_INCREMENT")
echo -e "\e[36mNew version: $NEW_VERSION\e[0m"

# 3. Update version in .toc file
sed -i "s/## Version: $CURRENT_VERSION/## Version: $NEW_VERSION/" LossPunishment.toc

# 4. Stage all changes
echo -e "\e[33mStaging changes...\e[0m"
git add .

# 5. Commit with message
FULL_COMMIT_MESSAGE="$COMMIT_MESSAGE (v$NEW_VERSION)"
echo -e "\e[33mCommitting: $FULL_COMMIT_MESSAGE\e[0m"
git commit -m "$FULL_COMMIT_MESSAGE"

# 6. Create tag
TAG_NAME="v$NEW_VERSION"
echo -e "\e[33mCreating tag: $TAG_NAME\e[0m"
git tag -a "$TAG_NAME" -m "Version $NEW_VERSION"

# 7. Push to GitHub
echo -e "\e[33mPushing to GitHub...\e[0m"
git push origin main
git push origin "$TAG_NAME"

echo -e "\e[32mDeployment complete!\e[0m"
echo -e "\e[32mVersion $NEW_VERSION has been pushed to GitHub.\e[0m"
echo -e "\e[32mGitHub Actions will now create a release automatically.\e[0m" 