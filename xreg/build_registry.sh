#!/bin/bash
# run on Linux and Windows with Git Bash

# Configuration
XRSERVER_COMMIT="be2be66"
CONTAINER_NAME="xregistry-server"
ARCHIVE_PATH="/tmp/xr_live_data.tar.gz"

# Detect platform
if [[ "$OSTYPE" == "msys" || "$OSTYPE" == "cygwin" || -n "$WINDIR" ]]; then
  IS_WINDOWS=true
  echo "Windows platform detected"
else
  IS_WINDOWS=false
  echo "Unix/Linux platform detected"
fi

# Determine repository root directory
SCRIPT_DIR=$(dirname "$(readlink -f "$PWD/$0")")
REPO_ROOT=$(readlink -f "$SCRIPT_DIR/..")
if [ -n "$GITHUB_ACTIONS" ]; then
  REPO_ROOT="$GITHUB_WORKSPACE"
  echo "Running on GitHub Actions. Using GITHUB_WORKSPACE as repository root: $REPO_ROOT"
fi
DATA_EXPORT_DIR="$REPO_ROOT/site/public/registry"
SITE_DIR="$REPO_ROOT/site"

echo "Script directory: $SCRIPT_DIR"
echo "Repository root directory: $REPO_ROOT"
echo "Data export directory: $DATA_EXPORT_DIR"
echo "Container name: $CONTAINER_NAME"
echo "Archive path: $ARCHIVE_PATH"
echo "xrserver commit: $XRSERVER_COMMIT"

# Function to execute Docker commands based on platform
docker_exec() {
  local container_id="$1"
  shift
  local command="$*"
  
  if [ "$IS_WINDOWS" = true ]; then
    # Use PowerShell for Windows to avoid path translation issues
    powershell.exe -Command "docker exec $container_id $command"
  else
    # Direct docker exec for Unix/Linux
    docker exec "$container_id" $command
  fi
}

# Function to execute complex Docker shell scripts
docker_exec_script() {
  local container_id="$1"
  local script_content="$2"
  
  if [ "$IS_WINDOWS" = true ]; then
    # Create temporary PowerShell script for Windows
    local temp_ps1="/tmp/docker_exec_$$.ps1"
    cat > "$temp_ps1" << EOF
param(\$ContainerId)
docker exec \$ContainerId sh -c @"
$script_content
"@
EOF
    powershell.exe -ExecutionPolicy Bypass -File "$temp_ps1" -ContainerId "$container_id"
    rm -f "$temp_ps1"
  else
    # Direct execution for Unix/Linux
    docker exec "$container_id" /bin/sh -c "$script_content"
  fi
}

# Construct the GitHub Pages URL for this repo (if running on GH Actions)
if [ -n "$GITHUB_ACTIONS" ]; then
  REPO_ORG=$(echo "$GITHUB_REPOSITORY" | awk -F/ '{print $1}')
  REPO_NAME=$(echo "$GITHUB_REPOSITORY" | awk -F/ '{print $2}')
  GITHUB_PAGES_URL="https://${REPO_ORG}.github.io/${REPO_NAME}/"
  echo "GitHub Pages URL: $GITHUB_PAGES_URL"
else
  REPO_NAME=$(basename "$REPO_ROOT")
  GITHUB_PAGES_URL="https://clemensv.github.io/xregistry-ai/"
fi

# Install Python dependencies
echo "Installing Python dependencies..."
yes | pip install pandas jsonpointer --quiet

# Generate unified model for all protocols
echo "Generating unified model from protocol definitions..."
cd "$SCRIPT_DIR"
python schema-generator.py --models --type xregistry-model --output model.json
cd "$REPO_ROOT"

# check out https://github.com/clemensv/xregistry-viewer into $SITE_DIR
if [ ! -d "$SITE_DIR" ]; then
  git clone https://github.com/clemensv/xregistry-viewer "$SITE_DIR"
else
  cd "$SITE_DIR"
  git pull
  cd "$REPO_ROOT"
fi

CONFIG_DIR="$SITE_DIR/public"
if [ -d "$CONFIG_DIR" ]; then
  for file in "$CONFIG_DIR"/config.json; do
    if [ -f "$file" ]; then
      tmpfile=$(mktemp)
      jq --arg url "${GITHUB_PAGES_URL}" '.baseUrl = $url' "$file" > "$tmpfile" && mv "$tmpfile" "$file"
      echo "Updated baseUrl in $file to ${GITHUB_PAGES_URL}"
    fi
  done
else
  echo "Config directory not found: $CONFIG_DIR"
fi

# update the base URL in the Angular app's index.html
INDEX_FILE="$SITE_DIR/src/index.html"
if [ -f "$INDEX_FILE" ]; then
  sed -i "s|<base href=\"/\">|<base href=\"$GITHUB_PAGES_URL\">|g" "$INDEX_FILE"
  echo "Updated base URL in $INDEX_FILE to $GITHUB_PAGES_URL"
else
  echo "Index file not found: $INDEX_FILE"
fi    

# copy the index.html file to 404.html
if [ -f "$INDEX_FILE" ]; then
  cp "$INDEX_FILE" "$SITE_DIR/src/404.html"
  echo "Copied $INDEX_FILE to $SITE_DIR/src/404.html"
else
  echo "Index file not found: $INDEX_FILE"
fi

# Replace the URL in environment.prod.ts
ENV_FILE="$SITE_DIR/src/environments/environment.prod.ts"
if [ -f "$ENV_FILE" ]; then
  sed -i "s|https://mcpxreg.org/registry|$GITHUB_PAGES_URL/registry|g" "$ENV_FILE"
  echo "Updated $ENV_FILE with GitHub Pages URL: $GITHUB_PAGES_URL"
else
  echo "Environment file not found: $ENV_FILE"
fi

# Build custom xrserver image if needed
XRSERVER_IMAGE="ghcr.io/xregistry/xrserver-all"

if [ -n "$XRSERVER_COMMIT" ] && [ "$XRSERVER_COMMIT" != "HEAD" ]; then
  echo "Building custom xrserver image with commit: $XRSERVER_COMMIT"
  
  # Create temporary directory for xrserver build
  XRSERVER_TEMP_DIR=$(mktemp -d)
  echo "Cloning xrserver repository to: $XRSERVER_TEMP_DIR"
  
  # Clone the xrserver repository
  git clone https://github.com/xregistry/server "$XRSERVER_TEMP_DIR"
  cd "$XRSERVER_TEMP_DIR"
  
  # Checkout the specified commit
  echo "Checking out commit: $XRSERVER_COMMIT"
  git checkout "$XRSERVER_COMMIT"
  
  # Build the xr and xrserver binaries
  echo "Building xr and xrserver binaries..."
  make xr xrserver
  
  # Create the .spec directory if using custom spec files
  if [ -n "$XR_SPEC" ]; then
    mkdir -p .spec
    # If you have XR_SPEC set, copy spec files
    cp -r "$XR_SPEC/"* .spec/ 2>/dev/null || true
  fi
  
  # Use commit hash for unique image tagging
  CUSTOM_IMAGE_TAG="xrserver-all:$XRSERVER_COMMIT"
  
  # Build the Docker image with unique tag
  echo "Building custom xrserver-all Docker image with tag: $CUSTOM_IMAGE_TAG"
  docker build -f misc/Dockerfile-all \
    --build-arg GIT_COMMIT=$(git rev-list -1 HEAD) \
    -t "$CUSTOM_IMAGE_TAG" \
    --no-cache .
  
  # Use the custom built image with unique tag
  XRSERVER_IMAGE="$CUSTOM_IMAGE_TAG"
  
  # Return to original directory
  cd "$REPO_ROOT"
  
  # Clean up temporary directory
  rm -rf "$XRSERVER_TEMP_DIR"
  
  echo "Custom xrserver image built successfully: $XRSERVER_IMAGE"
else
  echo "Using default xrserver image: $XRSERVER_IMAGE"
fi

# Start or reuse the xregistry server container
if [ "$(docker ps -q -f name="${CONTAINER_NAME}")" ]; then
  echo "Container ${CONTAINER_NAME} is already running."
  CONTAINER_ID=$(docker ps -q -f name="${CONTAINER_NAME}")
else
  # Remove any existing stopped container with the same name
  if [ "$(docker ps -aq -f name="${CONTAINER_NAME}")" ]; then
    docker rm "${CONTAINER_NAME}" > /dev/null 2>&1
  fi
  CONTAINER_ID=$(docker run -d --name "${CONTAINER_NAME}" -v $REPO_ROOT:/workspace -p 8080:8080 $XRSERVER_IMAGE --recreatedb)
fi

# Wait for the server to be ready
echo "Waiting for xregistry server to be ready..."
until curl --silent --get http://localhost:8080 -i | grep "200 OK" > /dev/null; do
  sleep 5
done

# Update the model
echo "Updating model..."
docker exec "${CONTAINER_ID}" /bin/bash ls -l /workspace
docker exec "${CONTAINER_ID}" /xr model update /workspace/xreg/model.json -s localhost:8080

# Create entries for each registry index.json
echo "Creating registry entries..."
echo "First, let's see what registry files exist:"
docker exec "${CONTAINER_ID}" find /workspace/registry -name "index.json" | head -5

echo "Now creating entries..."
docker exec "${CONTAINER_ID}" /bin/sh -c '
REGISTRY_DIR=/workspace/registry

# Find all index.json files, sort them, and process by depth (group level first, then resource level)
find $REGISTRY_DIR -type f -name index.json | \
sed "s|^$REGISTRY_DIR/||" | \
sort | \
awk -F/ "{print NF-1, \$0}" | \
sort -n -k1,1 | \
cut -d" " -f2- | \
while read relative_path; do
  file="$REGISTRY_DIR/$relative_path"
  path=${relative_path%/index.json}
  echo "Creating entry for path: /$path from file: $file"
  /xr create "/$path" -d "@$file" -s localhost:8080
  if [ $? -ne 0 ]; then
    echo "Error processing file: $file"
  else
    echo "Successfully processed file: $file"
  fi 
done
'

# Export the live data as a tarball
echo "Exporting live data to $ARCHIVE_PATH..."
echo "First, let's verify the xr server has entries:"
docker exec "${CONTAINER_ID}" /xr list -s localhost:8080 || echo "xr list failed"

echo "Now downloading registry data..."
docker exec "${CONTAINER_ID}" /bin/sh -c "
  mkdir -p /tmp/live
  echo 'Running xr download...'
  /xr download -s localhost:8080 /tmp/live -u https://mcpxreg.com/registry --index index.html
  echo 'Download completed. Directory contents:'
  ls -la /tmp/live/
  echo 'Creating tarball...'
  cd /tmp/live
  tar czf $ARCHIVE_PATH .
  echo 'Tarball created.'
"

# Copy the archive to the host
echo "Copying archive to $DATA_EXPORT_DIR..."
mkdir -p "$DATA_EXPORT_DIR"
docker cp "${CONTAINER_ID}:$ARCHIVE_PATH" "$DATA_EXPORT_DIR/xr_live_data.tar.gz"
tar xzf "$DATA_EXPORT_DIR/xr_live_data.tar.gz" -C "$DATA_EXPORT_DIR"
rm "$DATA_EXPORT_DIR/xr_live_data.tar.gz"

# Stop and remove the container
echo "Stopping and removing xregistry server..."
docker stop "${CONTAINER_ID}"
docker rm "${CONTAINER_ID}"
echo "xregistry server stopped and removed."

# verify that the data export directory contains an index.html file
echo "Verifying registry files were generated..."
echo "Looking for index.html in: $DATA_EXPORT_DIR/"
ls -la "$DATA_EXPORT_DIR/" | head -10

if [ ! -f "$DATA_EXPORT_DIR/index.html" ]; then
  echo "Error: Data export directory does not contain an index.html file."
  echo "Expected: $DATA_EXPORT_DIR/index.html"
  echo "Directory contents:"
  ls -la "$DATA_EXPORT_DIR/"
  exit 1
fi

# Build the index
echo "Building index..."
python "$REPO_ROOT/index/build_index.py"

# Copy additional files
echo "Copying flex.json files to $DATA_EXPORT_DIR..."
cp $REPO_ROOT/index/flex/*.flex.json $DATA_EXPORT_DIR

# Generate unified schemas
echo "Generating unified schemas..."
mkdir -p "$DATA_EXPORT_DIR/schema" "$DATA_EXPORT_DIR/openapi"
cd "$SCRIPT_DIR"
if [ -f "schema-generator.py" ]; then
  python schema-generator.py --models --type json-schema --output "$DATA_EXPORT_DIR/schema/json-schema.json" || echo "Warning: JSON schema generation failed"
  python schema-generator.py --models --type openapi --output "$DATA_EXPORT_DIR/openapi/openapi.json" || echo "Warning: OpenAPI schema generation failed"
  python schema-generator.py --models --type avro-schema --output "$DATA_EXPORT_DIR/schema/avro-schema.json" || echo "Warning: Avro schema generation failed"
else
  echo "Warning: schema-generator.py not found in $SCRIPT_DIR"
fi
cd "$REPO_ROOT"

# Skip Angular app build for now - deploy registry data directly
echo "Preparing static registry site..."
BUILD_OUTPUT="public/registry"

# Create a simple root index.html that redirects to the registry
mkdir -p "$SITE_DIR/public"

# Copy root Azure Static Web Apps configuration
echo "Copying root Azure Static Web Apps configuration..."
cp $REPO_ROOT/xreg/root-staticwebapp.config.json $SITE_DIR/public/staticwebapp.config.json
echo "Copied root config to: $SITE_DIR/public/staticwebapp.config.json"

cat > "$SITE_DIR/public/index.html" << 'EOF'
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>xRegistry AI</title>
    <meta http-equiv="refresh" content="0;url=./registry/">
    <style>
        body { font-family: Arial, sans-serif; text-align: center; padding: 50px; }
        a { color: #007bff; text-decoration: none; }
        a:hover { text-decoration: underline; }
    </style>
</head>
<body>
    <h1>xRegistry AI</h1>
    <p>Redirecting to <a href="./registry/">registry</a>...</p>
    <script>window.location.href = './registry/';</script>
</body>
</html>
EOF

# Stage the registry content into the 'static-site' branch
echo "Staging build output into 'static-site' branch..."

# Save the current branch name (default to main if not found)
CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "main")

TMP_DIR=$(mktemp -d)
echo "Cloning repository into temporary directory: $TMP_DIR"
branch="static-site"

# Determine the repository URL with authentication
if [ -n "$GITHUB_ACTIONS" ]; then
  REPO_URL="https://github-actions:$GITHUB_TOKEN@github.com/$GITHUB_REPOSITORY.git"
else
  REPO_URL=$(git remote get-url origin)
fi

if git ls-remote --exit-code --heads "$REPO_URL" "$branch" &> /dev/null; then
    git clone "$REPO_URL" "$TMP_DIR" -b "$branch" > /dev/null
else
    echo "Branch $branch does not exist. Cloning default branch instead."
    git clone "$REPO_URL" "$TMP_DIR" > /dev/null
fi

cd "$TMP_DIR"

# Create an orphan static-site branch (or reset it if it already exists)
if git show-ref --quiet refs/heads/static-site; then
  git checkout static-site
  git rm -rf . > /dev/null 2>&1 || true
else
  git checkout --orphan static-site
  git reset --hard
fi

# Clean the branch and copy in the build output from the main repo
find "$TMP_DIR" -mindepth 1 -maxdepth 1 ! -name ".git" -exec rm -rf {} +
if [ -d "$SITE_DIR/public" ]; then
  # Copy the entire public directory content to the root of static-site
  cp -r $SITE_DIR/public/* "$TMP_DIR"
  echo "Deployed static registry site from $SITE_DIR/public"
else
  echo "Warning: Static site content not found at $SITE_DIR/public"
  echo "Creating minimal index.html..."
  echo '<!DOCTYPE html><html><body><h1>Static site build in progress...</h1></body></html>' > "$TMP_DIR/index.html"
fi

touch .nojekyll

git add .
git commit -m "Deploy static registry site to static-site" || echo "Nothing to commit"

echo "Build output staged in static-site branch in temporary dir: $TMP_DIR"

# Push the changes to the static-site branch
git push origin static-site
cd "$REPO_ROOT"
git checkout "$CURRENT_BRANCH"

echo "Process complete." 
