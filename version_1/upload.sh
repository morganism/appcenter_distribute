#!/bin/bash
set -e

CONFIG=$@
for line in $CONFIG; do
  eval "$line"
done
echo "token=$token"
echo "owner=$owner"
echo "app=$app"

AUTH="X-API-Token: $token"
CONTENT_TYPE="application/vnd.android.package-archive"


<< 'COMMENT'
    "/v0.1/apps/{owner_name}/{app_name}/uploads/releases": {
      "post": {
        "description": "Initiate a new release upload. This API is part of multi-step upload process.",
        "operationId": "releases_createReleaseUpload",
        "parameters": [
          {
            "name": "body",
            "in": "body",
            "description": "Optional parameters to create releases with user defined metadata",
            "required": false,
            "schema": {
              "properties": {
                "build_version": {
                  "description": "User defined build version",
                  "type": "string"
                },
                "build_number": {
                  "description": "User defined build number",
                  "type": "string"
                }
              }
            }
          },
          {
            "name": "owner_name",
            "type": "string",
            "in": "path",
            "description": "The name of the owner",
            "required": true,
            "x-ms-parameter-location": "method"
          },
          {
            "name": "app_name",
            "type": "string",
            "in": "path",
            "description": "The name of the application",
            "required": true,
            "x-ms-parameter-location": "method"
          }
        ],
        "responses": {
          "201": {
            "description": "Created",
            "schema": {
              "properties": {
                "id": {
                  "description": "The ID for the newly created upload. It is going to be required later in the process.",
                  "type": "string",
                  "format": "uuid"
                },
                "upload_domain": {
                  "description": "The URL domain used to upload the release.",
                  "type": "string"
                },
                "token": {
                  "description": "The access token used for upload permissions.",
                  "type": "string"
                },
                "url_encoded_token": {
                  "description": "The access token used for upload permissions (URL encoded to use as a single query parameter).",
                  "type": "string"
                },
                "package_asset_id": {
                  "description": "The associated asset ID in the file management service associated with this uploaded.",
                  "type": "string",
                  "format": "uuid"
                }
              },
              "required": [
                "id",
                "upload_domain",
                "token",
                "url_encoded_token",
                "package_asset_id"
              ]
            }
          },
          "400": {
            "description": "The request contained invalid properties.",
            "schema": {
              "properties": {
                "code": {
                  "type": "string",
                  "enum": [
                    "BadRequest",
                    "Conflict",
                    "NotAcceptable",
                    "NotFound",
                    "InternalServerError",
                    "Unauthorized",
                    "TooManyRequests"
                  ]
                },
                "message": {
                  "type": "string"
                }
              },
              "required": [
                "code",
                "message"
              ]
            }
          },
          "404": {
            "description": "Error codes:\n- `not_found` - The app doesn't exist.\n",
            "schema": {
              "properties": {
                "code": {
                  "type": "string",
                  "enum": [
                    "BadRequest",
                    "Conflict",
                    "NotAcceptable",
                    "NotFound",
                    "InternalServerError",
                    "Unauthorized",
                    "TooManyRequests"
                  ]
                },
                "message": {
                  "type": "string"
                }
              },
              "required": [
                "code",
                "message"
              ]
            }
          }
        },
        "security": [
          {
            "APIToken": []
          }
        ],
        "tags": [
          "distribute"
        ]
      }
    },
COMMENT

echo "Creating release (1/7)"

request_url="https://api.appcenter.ms/v0.1/apps/$owner/$app/uploads/releases"
payload='{"build_version": "1", "build_number": "1"}'
payload='{"build_version": "1", "build_number": "1.0"}'
payload='{"build_version": "1.0", "build_number": "1"}'
payload='{"build_version": "1.0", "build_number": "1.0"}'

payload='{"build_version": "1", "build_number": "1.0"}'
payload='{"build_version": "1", "build_number": "1"}'
payload='{"build_version": "1.0", "build_number": "1"}'

payload='{"build_version": "20"}'


#content_length=$(echo $payload | wc -c)
#curl_cmd="curl -s -X POST -H \"Content-Type: application/json\" -H \"Content-length: ${content_length}\" -H \"Accept: application/json\" -H \"X-API-Token: $token\" -d \"${payload}\" \"$request_url\""
# bail on Content-length Header maybe only needed if length is 0 ??
curl_headers='-H "Content-Type: application/json" -H "Accept: application/json" -H "X-API-Token: '"$token"'"'
curl_cmd="curl -s -X POST $curl_headers -d '${payload}' '$request_url'"
echo "curl command is: [${curl_cmd}]"
echo "5 seconds until barf"
sleep 5
echo "Done sleeping"
upload_json=$(eval $curl_cmd)
echo "after upload_json"


echo "JSON=[${upload_json}]"

ID=$(echo $upload_json | jq -r '.id')
UPLOAD_DOMAIN=$(echo $upload_json | jq -r '.upload_domain')
PACKAGE_ASSET_ID=$(echo $upload_json | jq -r '.package_asset_id')
URL_ENCODED_TOKEN=$(echo $upload_json | jq -r '.url_encoded_token')

FILE_NAME=$(basename $file)
FILE_SIZE=$(stat --printf="%s" $file)

echo "Checkpoint"
echo "  UPLOAD_DOMAIN=${UPLOAD_DOMAIN}"
echo "  PACKAGE_ASSET_ID=${PACKAGE_ASSET_ID}"
echo "  URL_ENCODED_TOKEN=${URL_ENCODED_TOKEN}"

echo "Creating metadata (2/7)"
set_metadata_url="$UPLOAD_DOMAIN/upload/set_metadata/$PACKAGE_ASSET_ID?file_name=$FILE_NAME&file_size=$FILE_SIZE&token=$URL_ENCODED_TOKEN&content_type=$CONTENT_TYPE"
meta_response=$(curl -s -d POST -H "Content-Type: application/json" -H "Accept: application/json" -H "X-API-Token: $token" "$set_metadata_url")
chunk_size=$(echo $meta_response | jq -r '.chunk_size')

TMP_BUILD_DIR=${HOME}/build/appcenter-tmp

rm -rf $TMP_BUILD_DIR
mkdir $TMP_BUILD_DIR
split -b $chunk_size $file $TMP_BUILD_DIR/split


echo "Uploading chunked binary (3/7)"
binary_upload_url="$UPLOAD_DOMAIN/upload/upload_chunk/$PACKAGE_ASSET_ID?token=$URL_ENCODED_TOKEN"

block_number=1
for f in $TMP_BUILD_DIR/*
do
    url="$binary_upload_url&block_number=$block_number"
    size=$(stat --printf="%s" $f)
    curl -X POST $url --data-binary "@$f" -H "Content-Length: $size" -H "Content-Type: $CONTENT_TYPE"
    block_number=$(($block_number + 1))
    printf "\n"
done

echo "Finalising upload (4/7)"
finish_url="$UPLOAD_DOMAIN/upload/finished/$PACKAGE_ASSET_ID?token=$URL_ENCODED_TOKEN"
curl -d POST -H "Content-Type: application/json" -H "Accept: application/json" -H "X-API-Token: $token" "$finish_url"

echo "Commit release (5/7)"
commit_url="https://api.appcenter.ms/v0.1/apps/$owner/$app/uploads/releases/$ID"

echo "commit_url[${commit_url}]"

echo curl -H "'Content-Type: application/json'" -H "'Accept: application/json'" -H "'X-API-Token: $token'" --data '{"upload_status": "uploadFinished","id": "'"$ID"'"}' -X PATCH $commit_url


curl -H "Content-Type: application/json" -H "Accept: application/json" -H "X-API-Token: $token" \
  --data '{"upload_status": "uploadFinished","id": "$ID"}' \
  -X PATCH \
  $commit_url

release_status_url="https://api.appcenter.ms/v0.1/apps/$owner/$app/uploads/releases/$ID"


echo "RSURSURSU"
echo "release_status_url[${release_status_url}]"
echo "RSURSURSU"


release_id=null
counter=0
max_poll_attempts=15

echo "Polling for release id (6/7)"
while [[ $release_id == null && ($counter -lt $max_poll_attempts)]]
do

echo curl -s -H "'Content-Type: application/json'" -H "'Accept: application/json'" -H "'X-API-Token: $token'"   $release_status_url


    poll_result=$(curl -s -H "Content-Type: application/json" -H "Accept: application/json" -H "X-API-Token: $token" $release_status_url)

echo "POLL_RESULT[${poll_result}]"


    release_id=$(echo $poll_result | jq -r '.release_distinct_id')
    echo $counter $release_id
    counter=$((counter + 1))
    echo "XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX"
    sleep 3
done

if [[ $release_id == null ]];
then
    echo -e "\x1b[31m Failed to find release from appcenter \x1b[0m"
    exit 1
else
    echo -e "Status: \x1b[32m SUCCESS! \x1b[0m"
fi

echo "Applying destination to release (7/7)"
distribute_url="https://api.appcenter.ms/v0.1/apps/$owner/$app/releases/$release_id"

echo "distribute_url[${distribute_url}]"

json_data='{"destinations": [{ "name": "Internal" }, { "name": "External" }, { "name": "Collaborators" }] }'
echo "json_data=[$json_data]"

distribute_cmd="curl -H 'Content-Type: application/json' -H 'Accept: application/json' -H 'X-API-Token: $token' --data '$json_data' -X PATCH '$distribute_url'"

echo "distribute_cmd=[$distribute_cmd]"
distribute_cmd_result=$("$distribute_cmd")

echo "distribute_cmd_result=[$distribute_cmd_result]"


echo https://appcenter.ms/orgs/$owner/apps/$app/distribute/releases/$release_id
