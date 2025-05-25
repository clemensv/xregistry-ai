#!/bin/bash
# run on Linux

CONTAINER_NAME="xregistry-server"
ARCHIVE_PATH="/tmp/xr_live_data.tar.gz"

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

# Start or reuse the xregistry server container
if [ "$(docker ps -q -f name="${CONTAINER_NAME}")" ]; then
  echo "Container ${CONTAINER_NAME} is already running."
  CONTAINER_ID=$(docker ps -q -f name="${CONTAINER_NAME}")
else
  # Remove any existing stopped container with the same name
  if [ "$(docker ps -aq -f name="${CONTAINER_NAME}")" ]; then
    docker rm "${CONTAINER_NAME}" > /dev/null 2>&1
  fi
  CONTAINER_ID=$(docker run -d --name "${CONTAINER_NAME}" -v $REPO_ROOT:/workspace -p 8080:8080 ghcr.io/xregistry/xrserver-all --recreatedb)
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
docker exec "${CONTAINER_ID}" /bin/sh -c '
 REGISTRY_DIR=/workspace/registry
 find $REGISTRY_DIR -type f -name index.json | while read file; do
   path=${file#"$REGISTRY_DIR"/}
   path=${path%/index.json}
   /xr create "$path" -d "@$file" -s localhost:8080
   if [ $? -ne 0 ]; then
     echo "Error processing file: $file"
   else
     echo "Processed file: $file"
   fi 
 done
'

# Export the live data as a tarball
echo "Exporting live data to $ARCHIVE_PATH..."
docker exec "${CONTAINER_ID}" /bin/sh -c "
  mkdir -p /tmp/live
  /xr download -s localhost:8080 /tmp/live -u $GITHUB_PAGES_URL/registry --index index.html
  cd /tmp/live
  tar czf $ARCHIVE_PATH .
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

# Build the index
echo "Building index..."
python "$REPO_ROOT/index/build_index.py"

# Copy additional files
echo "Copying flex.json files to $REPO_ROOT/site/public/registry/..."
cp $REPO_ROOT/index/flex/*.flex.json $DATA_EXPORT_DIR
cp $REPO_ROOT/xreg/registry-staticwebapp.config.json $DATA_EXPORT_DIR/staticwebapp.config.json

# Generate unified schemas
echo "Generating unified schemas..."
mkdir -p "$DATA_EXPORT_DIR/schema" "$DATA_EXPORT_DIR/openapi"
cd "$SCRIPT_DIR"
python schema-generator.py --models --type json-schema --output "$DATA_EXPORT_DIR/schema/json-schema.json"
python schema-generator.py --models --type openapi --output "$DATA_EXPORT_DIR/openapi/openapi.json"
python schema-generator.py --models --type avro-schema --output "$DATA_EXPORT_DIR/schema/avro-schema.json"
cd "$REPO_ROOT"

# Build the Angular app
echo "Building the Angular app..."
BUILD_OUTPUT="dist/xregistry-viewer"
cd "$SITE_DIR"
if [ -f "package.json" ]; then
  npm install 
  npm run build-prod -- --base-href="$GITHUB_PAGES_URL"
fi

# Stage the build output into the 'static-site' branch
echo "Staging build output into 'static-site' branch..."

# Save the current branch name (default to main if not found)
CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "main")

TMP_DIR=$(mktemp -d)
echo "Cloning repository into temporary directory: $TMP_DIR"
branch="static-site"

# Determine the repository URL
if [ -n "$GITHUB_ACTIONS" ]; then
  REPO_URL="https://github.com/$GITHUB_REPOSITORY.git"
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
cp -r $SITE_DIR/$BUILD_OUTPUT/* "$TMP_DIR"

touch .nojekyll

git add .
git commit -m "Deploy Angular app to static-site" || echo "Nothing to commit"

echo "Build output staged in static-site branch in temporary dir: $TMP_DIR"

# Push the changes to the static-site branch
git push origin static-site
cd "$REPO_ROOT"
git checkout "$CURRENT_BRANCH"

echo "Process complete." 